#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem>
#include <QJSValue>
#include <QMimeData>
#include <QDragEnterEvent>
#include <QDropEvent>
#include <QInputMethodEvent>
#include <QTest>
#include <iostream>

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    QQuickView view;
    view.setSource(QUrl::fromLocalFile(argv[1]));
    if (view.status() != QQuickView::Ready) return 1;
    view.show(); view.requestActivate();
    if (!QTest::qWaitForWindowExposed(&view)) return 2;
    QTest::qWait(150);
    auto adapter = view.rootObject()->findChild<QObject *>("inputAdapter");
    auto dialog = view.rootObject()->findChild<QObject *>("attachmentFileDialog");
    if (!adapter || !dialog) return 3;
    QList<QUrl> urls{QUrl::fromLocalFile(argv[2]), QUrl::fromLocalFile(argv[3])};
    QMimeData mime;
    mime.setUrls(urls);
    QDragEnterEvent enter(QPoint(280, 80), Qt::CopyAction, &mime, Qt::LeftButton, Qt::NoModifier);
    QGuiApplication::sendEvent(&view, &enter);
    if (!enter.isAccepted()) return 4;
    QDropEvent drop(QPointF(280, 80), Qt::CopyAction, &mime, Qt::LeftButton, Qt::NoModifier);
    QGuiApplication::sendEvent(&view, &drop);
    QTest::qWait(50);
    auto values = adapter->property("paths").value<QJSValue>().toVariant().toList();
    if (!drop.isAccepted() || values.size() != 2 || values[0].toString() != urls[0].toString()) return 5;
    adapter->setProperty("paths", QVariantList{});
    // Qt selectedFiles is read-only. Set one real selectedFile, then exercise
    // its accepted callback; the native two-file drop above covers URL lists.
    if (!dialog->setProperty("selectedFile", urls[0])) return 6;
    if (!QMetaObject::invokeMethod(dialog, "accepted")) return 7;
    values = adapter->property("paths").value<QJSValue>().toVariant().toList();
    if (values.size() != 1 || values[0].toString() != urls[0].toString()) return 8;
    std::cout << "PASS: native QDragEnterEvent/QDropEvent with two local URLs and Qt FileDialog selection both reach the common attachment path\n";
    for (const auto &names : {std::pair{"messageEditor", "inputAdapter"}, std::pair{"notificationReplyEditor", "inputReply"}}) {
        auto editor = view.rootObject()->findChild<QQuickItem *>(names.first);
        auto model = view.rootObject()->findChild<QObject *>(names.second);
        if (!editor || !model) return 9;
        editor->forceActiveFocus(Qt::TabFocusReason);
        for (auto key : {Qt::Key_H, Qt::Key_J, Qt::Key_K, Qt::Key_L}) QTest::keyClick(&view, key);
        QInputMethodEvent preedit(QString::fromUtf8("に"), {});
        QGuiApplication::sendEvent(editor, &preedit);
        if (editor->property("preeditText").toString().isEmpty()) return 10;
        QTest::keyClick(&view, Qt::Key_Return);
        if (model->property("sendCount").toInt() != 0) return 11;
        QInputMethodEvent commit;
        commit.setCommitString(QString::fromUtf8("に"));
        QGuiApplication::sendEvent(editor, &commit);
        QTest::keyClick(&view, Qt::Key_Return, Qt::ShiftModifier);
        if (model->property("sendCount").toInt() != 0) return 12;
        if (!editor->property("text").toString().contains("hjkl") || !editor->property("text").toString().contains(QString::fromUtf8("に"))) return 13;
        QTest::keyClick(&view, Qt::Key_Return);
        if (model->property("sendCount").toInt() != 1) return 14;
    }
    std::cout << "PASS: actual QInputMethodEvent preedit/commit in composer and quick reply; composing Enter never sends, hjkl/Unicode/Shift+Enter preserved, plain Enter sends once\n";
}
