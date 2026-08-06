'use strict';
'require view';
'require form';
'require uci';
'require fs';
'require ui';

const CFG_CANDIDATES = [ 'dns_rewrite', 'aykc_dns' ];

return view.extend({
	load() {
		const tryLoad = (names) => {
			if (!names.length)
				return Promise.reject(new Error('no config'));
			const name = names[0];
			return uci.load(name).then(() => name).catch(() => tryLoad(names.slice(1)));
		};
		return tryLoad(CFG_CANDIDATES.slice()).then((cfg) => {
			this.cfgName = cfg;
			return cfg;
		});
	},

	render(cfgName) {
		const m = new form.Map(cfgName || this.cfgName || 'dns_rewrite', _('DNS Rewrites'),
			_('Manage local name overrides for the router DNS resolver (dnsmasq).') +
			'<br/><br/>' +
			'<ul>' +
			'<li>' + _('<strong>Private IP</strong> — answer with a fixed IPv4 address. ' +
				'The name is treated as local (no public AAAA mixed in). ' +
				'Use for hosts on your LAN, NAS, or other internal addresses.') + '</li>' +
			'<li>' + _('<strong>Public</strong> — resolve via the router upstream DNS ' +
				'(typically local DNS-over-HTTPS / your filtering resolver on 127.0.0.1#5053). ' +
				'Use when a name must follow public DNS (CDN, tunnel, external status page), ' +
				'especially if a private wildcard would otherwise catch it.') + '</li>' +
			'</ul>' +
			_('Domain patterns:') +
			'<ul>' +
			'<li><code>host.example.com</code> — single name</li>' +
			'<li><code>*.example.com</code> — all subdomains (not the apex <code>example.com</code>)</li>' +
			'<li><code>.example.com</code> — zone form used by dnsmasq for that domain tree</li>' +
			'</ul>' +
			_('More specific rows override wildcards (for example a single host IP wins over <code>*.example.com</code>).') +
			'<br/><br/>' +
			_('Save &amp; Apply writes configuration and restarts <strong>dnsmasq only</strong> (does not reload Wi-Fi).'));

		const s = m.section(form.GridSection, 'rewrite', _('Rules'));
		s.addremove = true;
		s.anonymous = true;
		s.sortable = true;
		s.nodescriptions = true;
		s.rowcolors = true;

		let o;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = o.enabled;
		o.editable = true;

		o = s.option(form.Value, 'domain', _('Domain'));
		o.rmempty = false;
		o.editable = true;
		o.placeholder = 'host.example.com';
		o.validate = function(section_id, value) {
			if (!value || !String(value).trim().length)
				return _('Domain is required');
			return true;
		};

		o = s.option(form.ListValue, 'type', _('Type'));
		o.value('private', _('Private IP'));
		o.value('public', _('Public (upstream DNS)'));
		o.rmempty = false;
		o.editable = true;

		o = s.option(form.Value, 'ip', _('IPv4 address'));
		o.datatype = 'ip4addr';
		o.placeholder = '192.168.1.10';
		o.depends('type', 'private');
		o.editable = true;
		o.rmempty = true;

		return m.render();
	},

	handleSaveApply(ev, mode) {
		return this.handleSave(ev).then(() => {
			return fs.exec('/usr/sbin/dns-rewrite-apply', []).then((res) => {
				if (res && res.code && res.code !== 0)
					throw new Error((res.stderr || res.stdout || 'apply failed').toString());
				ui.addNotification(null, E('p', _('DNS rewrites applied; dnsmasq restarted.')), 'info');
			});
		}).catch((e) => {
			ui.addNotification(null, E('p', _('Error: %s').format(e.message || e)), 'error');
		});
	}
});
