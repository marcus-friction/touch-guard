// SPDX-License-Identifier: MIT

import GObject from 'gi://GObject';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';
import {
    Extension,
    gettext as _,
} from 'resource:///org/gnome/shell/extensions/extension.js';

import {TouchController} from './controller.js';

const TouchToggle = GObject.registerClass(
class TouchToggle extends QuickSettings.QuickToggle {
    constructor(settings) {
        super({
            title: _('Touch Guard'),
            subtitle: _('Touchscreen enabled'),
            iconName: 'input-touchpad-symbolic',
            toggleMode: true,
        });

        this._settings = settings;
        this.connectObject('clicked', () => {
            this._settings.set_boolean('guarded', this.checked);
        }, this);
    }

    setState(state) {
        this.checked = state.desired;
        if (state.error)
            this.subtitle = _('Could not guard touchscreen');
        else if (state.pending)
            this.subtitle = state.desired
                ? _('Guarding touchscreen…')
                : _('Restoring touch…');
        else if (state.active)
            this.subtitle = _('Touchscreen guarded');
        else if (state.desired)
            this.subtitle = _('Waiting for touchscreen');
        else
            this.subtitle = _('Touchscreen enabled');
    }

    destroy() {
        this.disconnectObject(this);
        this._settings = null;
        super.destroy();
    }
});

const TouchIndicator = GObject.registerClass(
class TouchIndicator extends QuickSettings.SystemIndicator {
    constructor(settings) {
        super();
        this._indicator = this._addIndicator();
        this._indicator.icon_name = 'changes-prevent-symbolic';
        this._indicator.visible = false;
        this._toggle = new TouchToggle(settings);
        this.quickSettingsItems.push(this._toggle);
    }

    setState(state) {
        this._toggle.setState(state);
        this._indicator.visible = state.active;
    }

    destroy() {
        this.quickSettingsItems.forEach(item => item.destroy());
        this._toggle = null;
        this._indicator = null;
        super.destroy();
    }
});

export default class TouchGuardExtension extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._controller = new TouchController(
            state => this._indicator?.setState(state));
        this._indicator = new TouchIndicator(this._settings);
        Main.panel.statusArea.quickSettings.addExternalIndicator(
            this._indicator);

        this._settings.connectObject('changed::guarded', () => {
            this._controller.setDesired(
                this._settings.get_boolean('guarded'));
        }, this);
        this._controller.setDesired(this._settings.get_boolean('guarded'));
    }

    disable() {
        this._settings?.disconnectObject(this);
        this._controller?.dispose();
        this._controller = null;
        this._indicator?.destroy();
        this._indicator = null;
        this._settings = null;
    }
}
