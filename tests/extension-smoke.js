import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Scripting from 'resource:///org/gnome/shell/ui/scripting.js';

const UUID = 'touch-guard@marcus-friction.github.io';
const ACTIVE = 1;
const INACTIVE = 2;

export const METRICS = {};

function assert(condition, message) {
    if (!condition)
        throw new Error(message);
}

async function waitForState(expected) {
    for (let attempt = 0; attempt < 50; attempt++) {
        if (Main.extensionManager.lookup(UUID)?.state === expected)
            return;

        await Scripting.sleep(100);
    }

    const actual = Main.extensionManager.lookup(UUID)?.state;
    throw new Error(`Expected extension state ${expected}, got ${actual}`);
}

function assertUiCreated() {
    const extension = Main.extensionManager.lookup(UUID);

    assert(extension?.state === ACTIVE, 'extension should be active');
    assert(!extension.errors || extension.errors.length === 0,
        'extension should have no errors');
    assert(extension.stateObj?._indicator,
        'extension should create its Quick Settings indicator');
    assert(extension.stateObj._controller,
        'extension should create its touchscreen controller');
    assert(extension.stateObj._indicator.quickSettingsItems.length === 1,
        'indicator should contain exactly one Quick Settings tile');
}

export async function run() {
    await waitForState(ACTIVE);
    assertUiCreated();

    assert(Main.extensionManager.disableExtension(UUID),
        'extension should accept a disable request');
    await waitForState(INACTIVE);

    assert(Main.extensionManager.enableExtension(UUID),
        'extension should accept an enable request');
    await waitForState(ACTIVE);
    assertUiCreated();
}
