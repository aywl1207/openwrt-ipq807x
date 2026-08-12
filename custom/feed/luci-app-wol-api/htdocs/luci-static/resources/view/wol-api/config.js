'use strict';
'require view';
'require form';
'require uci';
'require ui';
'require network';

const CFG = 'wol_api';

function validateMac(section_id, value) {
	if (!value || !String(value).trim().length)
		return _('MAC is required');
	const m = String(value).trim();
	if (!/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(m))
		return _('Invalid MAC (AA:BB:CC:DD:EE:FF)');
	return true;
}

function validateName(section_id, value) {
	if (!value || !String(value).trim().length)
		return _('Name is required');
	if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$/.test(String(value).trim()))
		return _('Use letters, numbers, . _ -');
	return true;
}

/** Skip devices that cannot be etherwake -i targets */
function isWolIface(name) {
	if (!name || /@/.test(name))
		return false;
	if (/^(lo|ifb|teql|sit|gre|gretap|erspan|tun|tap|veth|wg|tailscale|miireg|dummy|bond)/.test(name))
		return false;
	return true;
}

return view.extend({
	load() {
		return Promise.all([
			uci.load(CFG),
			network.getDevices()
		]);
	},

	render([/* uci */, devices]) {
		const desc =
			_('Token-protected Wake-on-LAN HTTP API for Home Assistant (and other automations).') +
			'<br/><br/>' +
			'<strong>' + _('Endpoint') + '</strong>: <code>http://&lt;router-ip&gt;:8080/cgi-bin/wol</code>' +
			'<ul>' +
			'<li><code>?action=list&amp;token=TOKEN</code> — ' + _('list targets') + '</li>' +
			'<li><code>?target=NAME&amp;token=TOKEN</code> — ' + _('send magic packet') + '</li>' +
			'<li>' + _('Auth header') + ': <code>X-WOL-Token: TOKEN</code> ' + _('or') +
			' <code>Authorization: Bearer TOKEN</code></li>' +
			'</ul>' +
			_('Packets are sent from this router on the chosen bridge (correct for cross-subnet WOL).') +
			'<br/>' +
			_('Home Assistant: use rest_command pointing at this URL.') +
			'<br/><br/>' +
			'<em>' + _('Note: stock menu “Wake on LAN” is for manual wake only; this page configures the API.') + '</em>';

		const m = new form.Map(CFG, _('WOL API'), desc);

		const g = m.section(form.NamedSection, 'globals', 'wol_api', _('API settings'));
		g.addremove = false;
		g.anonymous = false;

		let o;
		o = g.option(form.Flag, 'enabled', _('Enable API'));
		o.default = o.enabled;
		o.rmempty = false;

		o = g.option(form.Value, 'token', _('API token'));
		o.password = true;
		o.rmempty = false;
		o.placeholder = _('long random secret');
		o.description = _('Required on every request. Keep private; HA stores it in rest_command.');

		o = g.option(form.Flag, 'allow_mac', _('Allow raw MAC in URL'));
		o.default = o.disabled;
		o.description = _('If enabled, ?mac=AA:BB:… works without a named target (less safe). Prefer named targets.');

		const s = m.section(form.GridSection, 'target', _('Wake targets'));
		s.addremove = true;
		s.anonymous = true;
		s.sortable = true;
		s.nodescriptions = true;
		s.rowcolors = true;
		s.addbtntitle = _('Add target');

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = o.enabled;
		o.editable = true;

		o = s.option(form.Value, 'name', _('Name'));
		o.rmempty = false;
		o.editable = true;
		o.placeholder = 'example-pc';
		o.validate = validateName;
		o.description = _('Used as ?target=NAME (case-insensitive).');

		o = s.option(form.Value, 'mac', _('MAC'));
		o.rmempty = false;
		o.editable = true;
		o.placeholder = 'AA:BB:CC:DD:EE:FF';
		o.validate = validateMac;
		o.write = function(section_id, value) {
			const n = String(value || '').trim().toUpperCase();
			return form.Value.prototype.write.apply(this, [section_id, n]);
		};

		/* Dynamic dropdown from live L2 devices (not hardcoded br-lan*) */
		o = s.option(form.ListValue, 'interface', _('Interface'));
		o.rmempty = false;
		o.editable = true;
		o.description = _('L2 device used by etherwake (-i). Prefer the bridge that owns the target subnet.');

		const labels = {};
		L.toArray(devices).forEach(function(dev) {
			const name = dev.getName && dev.getName();
			if (!isWolIface(name) || labels[name])
				return;
			const up = dev.isUp && dev.isUp();
			labels[name] = up ? name : '%s (%s)'.format(name, _('down'));
		});
		/* Keep configured values even if device currently missing */
		uci.sections(CFG, 'target').forEach(function(sec) {
			const cur = sec.interface;
			if (cur && !labels[cur])
				labels[cur] = '%s (%s)'.format(cur, _('absent'));
		});
		const names = Object.keys(labels).sort(L.naturalCompare);
		if (names.length) {
			names.forEach(function(name) {
				o.value(name, labels[name]);
			});
		}
		else {
			o.value('', _('(no suitable device found)'));
		}
		o = s.option(form.Flag, 'broadcast', _('Broadcast'));
		o.default = o.enabled;
		o.editable = true;
		o.description = _('Use etherwake -b (recommended).');

		return m.render();
	}
});
