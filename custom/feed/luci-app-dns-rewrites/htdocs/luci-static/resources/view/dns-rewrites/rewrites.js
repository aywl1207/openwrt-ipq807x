'use strict';
'require view';
'require form';
'require uci';
'require fs';
'require ui';

const CONF_PREVIEW = '/etc/dnsmasq.d/10-dns-rewrites.conf';
const CFG = 'dns_rewrite';

/** Domain pattern: host, *.zone, or .zone (optional trailing dot stripped later). */
function validateDomain(section_id, value) {
	if (!value || !String(value).trim().length)
		return _('Domain is required');

	const d = String(value).trim().replace(/\.+$/, '').toLowerCase();
	// single label / FQDN / wildcard / leading-dot zone
	if (!/^(\*\.)?([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$/.test(d) &&
	    !/^\.([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)*[a-z]{2,}$/.test(d) &&
	    !/^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$/.test(d) &&
	    !/^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/.test(d))
		return _('Invalid domain (use host.example.com, *.example.com, or .example.com)');

	return true;
}

function validatePrivateIp(section_id, value) {
	const type = uci.get(CFG, section_id, 'type') || 'private';
	if (type !== 'private')
		return true;
	if (!value || !String(value).trim().length)
		return _('IPv4 address is required for Private IP rules');
	return true;
}

return view.extend({
	load() {
		return Promise.all([
			uci.load(CFG),
			L.resolveDefault(fs.read(CONF_PREVIEW), '')
		]).then(([, preview]) => preview);
	},

	render(previewText) {
		const desc =
			_('Manage local name overrides for the router DNS resolver (dnsmasq).') +
			'<br/><br/>' +
			'<ul>' +
			'<li>' + _('<strong>Private IP</strong> — answer with a fixed IPv4 address. The name is treated as local (no public AAAA mixed in). Use for hosts on your LAN, NAS, or other internal addresses.') + '</li>' +
			'<li>' + _('<strong>Public</strong> — resolve via the configured upstream (default: https-dns-proxy listen address, usually 127.0.0.1#5053). Use when a name must follow public DNS, especially if a private wildcard would otherwise catch it.') + '</li>' +
			'</ul>' +
			_('Domain patterns:') +
			'<ul>' +
			'<li><code>host.example.com</code> — ' + _('single name') + '</li>' +
			'<li><code>*.example.com</code> — ' + _('all subdomains (not the zone apex)') + '</li>' +
			'<li><code>.example.com</code> — ' + _('dnsmasq zone form for that domain tree') + '</li>' +
			'</ul>' +
			_('More specific rows override wildcards (for example a single host IP wins over a wildcard).') +
			'<br/><br/>' +
			_('Save &amp; Apply writes configuration and restarts <strong>dnsmasq only</strong> when the generated file changes (does not reload Wi-Fi).');

		const m = new form.Map(CFG, _('DNS Rewrites'), desc);

		/* ---- globals ---- */
		const g = m.section(form.NamedSection, 'globals', 'dns_rewrite', _('Settings'));
		g.addremove = false;
		g.anonymous = false;

		let o;
		o = g.option(form.Value, 'upstream', _('Upstream for Public rules'));
		o.placeholder = '127.0.0.1#5053';
		o.rmempty = true;
		o.description = _('Leave empty to use https-dns-proxy listen address, then 127.0.0.1#5053. Format: host#port');
		o.validate = function(section_id, value) {
			if (!value || !String(value).trim().length)
				return true;
			const v = String(value).trim();
			/* dnsmasq-style host#port (hash, not colon) */
			if (!/^[0-9a-zA-Z._\[\]:-]+#\d{1,5}$/.test(v) &&
			    !/^[0-9a-zA-Z._\[\]:-]+$/.test(v))
				return _('Use host#port (e.g. 127.0.0.1#5053)');
			return true;
		};

		o = g.option(form.Value, 'description', _('Description'));
		o.rmempty = true;

		/* ---- rules ---- */
		const s = m.section(form.GridSection, 'rewrite', _('Rules'));
		s.addremove = true;
		s.anonymous = true;
		s.sortable = true;
		s.nodescriptions = true;
		s.rowcolors = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = o.enabled;
		o.editable = true;

		o = s.option(form.Value, 'domain', _('Domain'));
		o.rmempty = false;
		o.editable = true;
		o.placeholder = 'host.example.com';
		o.validate = validateDomain;
		o.write = function(section_id, value) {
			const n = String(value || '').trim().replace(/\.+$/, '').toLowerCase();
			return form.Value.prototype.write.apply(this, [section_id, n]);
		};

		o = s.option(form.ListValue, 'type', _('Type'));
		o.value('private', _('Private IP'));
		o.value('public', _('Public (upstream DNS)'));
		o.rmempty = false;
		o.editable = true;
		o.default = 'private';

		o = s.option(form.Value, 'ip', _('IPv4 address'));
		o.datatype = 'ip4addr';
		o.placeholder = '192.168.1.10';
		o.depends('type', 'private');
		o.editable = true;
		o.rmempty = true;
		o.validate = validatePrivateIp;

		o = s.option(form.Value, 'comment', _('Comment'));
		o.rmempty = true;
		o.editable = true;
		o.placeholder = _('optional note');
		o.modalonly = false;

		return m.render().then((nodes) => {
			const pre = E('pre', {
				'style': 'max-height:20em;overflow:auto;white-space:pre-wrap;font-size:12px;padding:0.75em;background:var(--background-color-high,#f6f6f6);border:1px solid var(--border-color-medium,#ccc);border-radius:4px;'
			}, previewText && String(previewText).length
				? String(previewText)
				: _('(empty or not applied yet — Save & Apply to generate)'));

			nodes.appendChild(E('div', { 'class': 'cbi-section', 'style': 'margin-top:1.5em' }, [
				E('h3', {}, _('Generated dnsmasq config')),
				E('p', { 'class': 'cbi-section-descr' },
					_('Read-only preview of %s after the last successful apply.').format(CONF_PREVIEW)),
				pre
			]));

			return nodes;
		});
	},

	handleSaveApply(ev, mode) {
		return this.handleSave(ev).then(() => {
			return fs.exec('/usr/sbin/dns-rewrite-apply', []).then((res) => {
				if (res && res.code && res.code !== 0)
					throw new Error((res.stderr || res.stdout || 'apply failed').toString());
				const out = (res.stdout || '').toString();
				const msg = out.indexOf('unchanged') !== -1
					? _('DNS rewrites unchanged; dnsmasq not restarted.')
					: _('DNS rewrites applied; dnsmasq restarted if needed.');
				ui.addNotification(null, E('p', msg), 'info');
				/* refresh preview without full navigation */
				return L.resolveDefault(fs.read(CONF_PREVIEW), '').then((text) => {
					const pre = document.querySelector('.cbi-section pre');
					if (pre)
						pre.textContent = text && String(text).length
							? String(text)
							: _('(empty or not applied yet — Save & Apply to generate)');
				});
			});
		}).catch((e) => {
			ui.addNotification(null, E('p', _('Error: %s').format(e.message || e)), 'error');
		});
	}
});
