#include <QChar>
#include <QBitArray>
#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem>
#include <QQmlEngine>
#include <QPointingDevice>
#include <QElapsedTimer>
#include <QWheelEvent>
#include <QTest>
#include <iostream>

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    QQuickView view;
    bool warnings = false;
    QObject::connect(view.engine(), &QQmlEngine::warnings, [&](const auto &) { warnings = true; });
    view.setSource(QUrl::fromLocalFile(argv[1]));
    if (view.status() != QQuickView::Ready) return 1;
    view.show(); view.requestActivate();
    if (!QTest::qWaitForWindowExposed(&view)) return 2;
    if (!QTest::qWaitFor([&] { return view.rootObject()->property("ready").toBool(); }, 5000)) return 3;
    QTest::qWait(200);
    QPointingDevice touchpad("test touchpad", 1, QInputDevice::DeviceType::TouchPad,
        QPointingDevice::PointerType::Finger, QInputDevice::Capability::Position, 2, 0);
    QElapsedTimer clock;
    clock.start();
    auto require = [](bool ok, const char *message) {
        if (!ok) { std::cerr << "FAIL: " << message << std::endl; std::exit(4); }
    };
    for (const auto name : {"conversationList", "messageHistory"}) {
        auto list = view.rootObject()->findChild<QQuickItem *>(name);
        require(list, "list exists");
        auto y = [&] { return list->property("contentY").toReal(); };
        auto moving = [&] { return list->property("moving").toBool(); };
        auto wheel = [&](Qt::ScrollPhase phase, int pixels, int angle = 0,
                         const QPointingDevice *device = nullptr) {
            const QPointF local = list->mapToScene(QPointF(list->width() / 2, list->height() / 2));
            QWheelEvent event(local, view.mapToGlobal(local.toPoint()), QPoint(0, pixels), QPoint(0, angle),
                Qt::NoButton, Qt::NoModifier, phase, false,
                phase == Qt::NoScrollPhase ? Qt::MouseEventNotSynthesized : Qt::MouseEventSynthesizedBySystem,
                device ? device : QPointingDevice::primaryPointingDevice());
            event.setTimestamp(clock.elapsed());
            QGuiApplication::sendEvent(&view, &event);
        };
        auto center = [&] {
            QMetaObject::invokeMethod(list, "cancelFlick");
            if (list->property("followEnd").isValid()) list->setProperty("followEnd", false);
            list->setProperty("contentY", list->property("originY").toReal() + 1400);
            QTest::qWait(150);
        };
        auto gesture = [&](int pixels, const QPointingDevice *device = nullptr) {
            wheel(Qt::ScrollBegin, 0, 0, device);
            for (int i = 0; i < 8; ++i) {
                QTest::qWait(16);
                wheel(Qt::ScrollUpdate, pixels, pixels * 2, device);
            }
        };
        for (const auto device : {QPointingDevice::primaryPointingDevice(), static_cast<const QPointingDevice *>(&touchpad)}) {
            for (int direction : {-1, 1}) {
                center();
                const auto start = y();
                gesture(direction * 28, device);
                require(direction * (start - y()) > 60, "pixel gesture scrolls in its original direction");
                wheel(Qt::ScrollEnd, 0, 0, device);
                const auto released = y();
                QTest::qWait(80);
                require(direction * (released - y()) > 15, "scroll continues after finger release");
                const auto first = y();
                const auto velocity = std::abs(list->property("verticalVelocity").toReal());
                QTest::qWait(80);
                require(direction * (first - y()) > 0, "momentum spans multiple frames");
                std::cout << name << " direction=" << direction << " release=" << released << " after80=" << first
                    << " after160=" << y() << " velocity80=" << velocity << " velocity160="
                    << std::abs(list->property("verticalVelocity").toReal()) << std::endl;
                require(std::abs(list->property("verticalVelocity").toReal()) < velocity, "momentum decelerates");
                require(QTest::qWaitFor([&] { return !moving(); }, 3000), "momentum settles");
            }
        }
        center(); gesture(-28);
        QTest::qWait(180);
        wheel(Qt::ScrollEnd, 0);
        const auto paused = y();
        QTest::qWait(200);
        require(std::abs(y() - paused) < 2, "pause before release does not revive old velocity");
        center(); gesture(-28); wheel(Qt::ScrollEnd, 0); QTest::qWait(50);
        wheel(Qt::ScrollBegin, 0);
        const auto interrupted = y();
        QTest::qWait(120);
        require(std::abs(y() - interrupted) < 2, "new finger gesture stops inertia");
        wheel(Qt::ScrollEnd, 0);
        center(); gesture(-28); wheel(Qt::ScrollEnd, 0); QTest::qWait(50);
        list->forceActiveFocus(Qt::TabFocusReason);
        QTest::keyClick(&view, Qt::Key_K);
        const auto keyed = y();
        QTest::qWait(180);
        require(std::abs(y() - keyed) < 2, "keyboard navigation cancels inertia");
        center();
        const auto beforeWheel = y();
        wheel(Qt::NoScrollPhase, 0, -120);
        require(QTest::qWaitFor([&] { return y() > beforeWheel + 5; }, 1000), "ordinary mouse wheel still scrolls");
        require(QTest::qWaitFor([&] { return !moving(); }, 3000), "mouse wheel settles");
        // Scroll against the top and bottom: no overshoot or wrong-direction coast.
        for (int direction : {-1, 1}) {
            QMetaObject::invokeMethod(list, direction > 0 ? "positionViewAtBeginning" : "positionViewAtEnd");
            QTest::qWait(100);
            const auto bound = y();
            gesture(direction * 28); wheel(Qt::ScrollEnd, 0);
            QTest::qWait(200);
            require(std::abs(y() - bound) < 2, "momentum respects list boundaries");
        }
        std::cout << "PASS: " << name << ": both directions, Wayland mouse/touchpad devices, deceleration, pause, interruption, keyboard, wheel and bounds\n";
    }
    if (argc > 2) require(view.grabWindow().save(argv[2]), "screenshot saved");
    require(!warnings, "no QML warnings");
}
