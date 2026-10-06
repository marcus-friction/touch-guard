// SPDX-License-Identifier: MIT

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

const HELPER = '/usr/local/libexec/touch-guard-helper';

export class TouchController {
    constructor(onStateChanged) {
        this._onStateChanged = onStateChanged;
        this._desired = false;
        this._active = false;
        this._pending = false;
        this._error = null;
        this._process = null;
        this._closing = false;
        this._disposed = false;
        this._stderr = '';
    }

    get state() {
        return {
            desired: this._desired,
            active: this._active,
            pending: this._pending,
            error: this._error,
        };
    }

    setDesired(desired) {
        if (this._disposed || this._desired === desired)
            return;

        this._desired = desired;
        this._error = null;
        if (desired) {
            if (!this._process)
                this._start();
            else
                this._publish();
        } else if (this._process) {
            this._stop();
        } else {
            this._active = false;
            this._pending = false;
            this._publish();
        }
    }

    dispose() {
        this._disposed = true;
        this._onStateChanged = null;
        this._closeStdin();
        this._process = null;
    }

    _publish() {
        this._onStateChanged?.(this.state);
    }

    _start() {
        this._active = false;
        this._pending = true;
        this._error = null;
        this._stderr = '';
        this._publish();

        try {
            this._process = Gio.Subprocess.new(
                ['pkexec', HELPER],
                Gio.SubprocessFlags.STDIN_PIPE |
                Gio.SubprocessFlags.STDOUT_PIPE |
                Gio.SubprocessFlags.STDERR_PIPE);
        } catch (error) {
            this._pending = false;
            this._error = error.message;
            this._publish();
            return;
        }

        const process = this._process;
        this._closing = false;
        this._readLines(new Gio.DataInputStream({
            base_stream: process.get_stdout_pipe(),
        }), line => this._handleOutput(process, line));
        this._readLines(new Gio.DataInputStream({
            base_stream: process.get_stderr_pipe(),
        }), line => {
            this._stderr = line;
        });

        process.wait_async(null, (source, result) => {
            try {
                source.wait_finish(result);
            } catch (error) {
                this._stderr = error.message;
            }

            if (this._disposed || this._process !== process)
                return;

            this._process = null;
            this._active = false;
            this._pending = false;
            if (this._desired) {
                if (this._closing) {
                    this._start();
                    return;
                }
                this._error ||= this._stderr || 'Touch Guard helper exited';
            } else {
                this._error = null;
            }
            this._publish();
        });
    }

    _readLines(stream, onLine) {
        const readNext = () => {
            stream.read_line_async(GLib.PRIORITY_DEFAULT, null,
                (source, result) => {
                    try {
                        const [line] = source.read_line_finish_utf8(result);
                        if (line === null)
                            return;
                        if (!this._disposed)
                            onLine(line);
                        readNext();
                    } catch (error) {
                        if (!this._disposed)
                            this._stderr = error.message;
                    }
                });
        };
        readNext();
    }

    _handleOutput(process, line) {
        if (this._process !== process || this._closing)
            return;

        if (line.startsWith('READY ')) {
            this._active = true;
            this._pending = false;
            this._error = null;
        } else if (line.startsWith('WAITING ')) {
            this._active = false;
            this._pending = false;
            this._error = null;
        } else if (line.startsWith('ERROR ')) {
            this._active = false;
            this._pending = false;
            this._error = line.slice(6);
            this._closeStdin();
        } else {
            return;
        }
        this._publish();
    }

    _closeStdin() {
        if (!this._process || this._closing)
            return;

        this._closing = true;
        try {
            this._process.get_stdin_pipe().close(null);
        } catch (error) {
            this._stderr = error.message;
        }
    }

    _stop() {
        this._pending = true;
        this._publish();
        this._closeStdin();
    }
}
