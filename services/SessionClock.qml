import Quickshell

SystemClock {
    precision: SystemClock.Minutes

    function refresh(): void {
        // 0.3.1 resamples wall time and schedules the next minute when enabled.
        // Its normal timer can retain the pre-suspend deadline after resume.
        enabled = false;
        enabled = true;
    }
}
