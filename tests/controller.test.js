const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const sourcePath = path.join(__dirname,
    '../touch-guard@marcus-friction.github.io/controller.js');
const source = fs.readFileSync(sourcePath, 'utf8')
    .replace(/^import .*;\n/gm, '')
    .replace('export class TouchController', 'class TouchController') +
    '\nglobalThis.TouchController = TouchController;\n';

const processes = [];
const sandbox = {
    Gio: {
        SubprocessFlags: {STDIN_PIPE: 1, STDOUT_PIPE: 2, STDERR_PIPE: 4},
        Subprocess: {
            new() {
                const process = {
                    closed: false,
                    get_stdin_pipe() {
                        return {close: () => { process.closed = true; }};
                    },
                    get_stdout_pipe() { return {}; },
                    get_stderr_pipe() { return {}; },
                    wait_async(_cancellable, callback) {
                        process.finish = () => callback(process, {});
                    },
                    wait_finish() { return true; },
                };
                processes.push(process);
                return process;
            },
        },
        DataInputStream: class {
            read_line_async() {}
        },
    },
    GLib: {PRIORITY_DEFAULT: 0},
};
vm.runInNewContext(source, sandbox, {filename: sourcePath});

const controller = new sandbox.TouchController(() => {});
controller.setDesired(true);
assert.equal(processes.length, 1);
controller._handleOutput(processes[0], 'ERROR permission denied');
assert.equal(processes[0].closed, true);
processes[0].finish();
assert.equal(processes.length, 1, 'a failed helper must not restart in a loop');
assert.equal(controller.state.error, 'permission denied');
assert.equal(controller.state.active, false);

controller.setDesired(false);
controller.setDesired(true);
assert.equal(processes.length, 2, 'turning the tile off and on retries');
controller.dispose();
assert.equal(processes[1].closed, true);

console.log('Controller tests passed.');
