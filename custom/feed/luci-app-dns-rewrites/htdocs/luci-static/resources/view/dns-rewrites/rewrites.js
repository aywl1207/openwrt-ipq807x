'use strict';
'require view';
'require form';
'require uci';
'require fs';
'require ui';
'require rpc';

const CONF_PREVIEW = '/etc/dnsmasq.d/10-dns-rewrites.conf';
const CFG = 'dns_rewrite';

/* Session overlay only — CLI `uci commit` cannot see LuCI Save. */
const callUciCommit = rpc.declare({
	object: 'uci',
	method: 'commit',
	params: [ 'config' ],
	reject: true
});

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
		return _('IPv4 is required for Private IP');
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
		/* Short copy: long technical paragraphs look awkward after zh-tw translation. */
		const desc =
			_('Override DNS names on this router (dnsmasq).') +
			'<br/><br/>' +
			'<ul>' +
			'<li>' + _('<strong>Private IP</strong>: always return a fixed IPv4 (LAN / NAS). Local only — no public AAAA.') + '</li>' +
			'<li>' + _('<strong>Public</strong>: look up via upstream DNS (default local DoH 127.0.0.1#5053). Use when a private wildcard would wrongly catch the name.') + '</li>' +
			'</ul>' +
			_('Name formats:') +
			'<ul>' +
			'<li><code>host.example.com</code> — ' + _('one host') + '</li>' +
			'<li><code>*.example.com</code> — ' + _('all subdomains (not the apex name)') + '</li>' +
			'<li><code>.example.com</code> — ' + _('whole domain tree') + '</li>' +
			'</ul>' +
			_('More specific rules win over wildcards.') +
			'<br/><br/>' +
			_('Save &amp; Apply updates the config. dnsmasq restarts only if the file changed (Wi-Fi is not touched).');

		const m = new form.Map(CFG, _('DNS Custom Rewrites'), desc);

		/* ---- globals ---- */
		const g = m.section(form.NamedSection, 'globals', 'dns_rewrite', _('Settings'));
		g.addremove = false;
		g.anonymous = false;

		let o;
		o = g.option(form.Value, 'upstream', _('Public upstream'));
		o.placeholder = '127.0.0.1#5053';
		o.rmempty = true;
		o.description = _('Optional. Empty = https-dns-proxy port, else 127.0.0.1#5053. Format host#port.');
		o.validate = function(section_id, value) {
			if (!value || !String(value).trim().length)
				return true;
			const v = String(value).trim();
			/* dnsmasq-style host#port (hash, not colon) */
			if (!/^[0-9a-zA-Z._\[\]:-]+#\d{1,5}$/.test(v) &&
			    !/^[0-9a-zA-Z._\[\]:-]+$/.test(v))
				return _('Invalid format (example: 127.0.0.1#5053)');
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
		o.rmempty = false;
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
		o.value('public', _('Public'));
		o.rmempty = false;
		o.editable = true;
		o.default = 'private';

		o = s.option(form.Value, 'ip', _('IPv4'));
		o.datatype = 'ip4addr';
		o.placeholder = '192.168.1.10';
		o.depends('type', 'private');
		o.editable = true;
		o.rmempty = true;
		o.validate = validatePrivateIp;

		o = s.option(form.Value, 'comment', _('Note'));
		o.rmempty = true;
		o.editable = true;
		o.placeholder = _('optional');
		o.modalonly = false;

		return m.render().then((nodes) => {
			const pre = E('pre', {
				'style': 'max-height:20em;overflow:auto;white-space:pre-wrap;font-size:12px;padding:0.75em;background:var(--background-color-high,#f6f6f6);border:1px solid var(--border-color-medium,#ccc);border-radius:4px;'
			}, previewText && String(previewText).length
				? String(previewText)
				: _('(not generated yet — use Save & Apply)'));

			nodes.appendChild(E('div', { 'class': 'cbi-section', 'style': 'margin-top:1.5em' }, [
				E('h3', {}, _('Generated config')),
				E('p', { 'class': 'cbi-section-descr' },
					_('Preview of %s').format(CONF_PREVIEW)),
				pre
			]));

			return nodes;
		});
	},

	handleSaveApply(ev, mode) {
		/* handleSave() writes the rpcd session overlay only. Commit that
		   package via ubus (not CLI), then generate dnsmasq conf.
		   Skip ui.changes.apply() — it reloads network/wifi. */
		return this.handleSave(ev).then(() => {
			return callUciCommit(CFG);
		}).then(() => {
			return fs.exec('/usr/sbin/dns-rewrite-apply', []).then((res) => {
				if (res && res.code && res.code !== 0)
					throw new Error((res.stderr || res.stdout || 'apply failed').toString());
				const out = (res.stdout || '').toString();
				const msg = out.indexOf('unchanged') !== -1
					? _('No change; dnsmasq not restarted.')
					: _('Applied; dnsmasq restarted if needed.');
				ui.addNotification(null, E('p', msg), 'info');
				return L.resolveDefault(fs.read(CONF_PREVIEW), '').then((text) => {
					const pre = document.querySelector('.cbi-section pre');
					if (pre)
						pre.textContent = text && String(text).length
							? String(text)
							: _('(not generated yet — use Save & Apply)');
					if (ui.changes && typeof ui.changes.init === 'function')
						return ui.changes.init();
				});
			});
		}).catch((e) => {
			ui.addNotification(null, E('p', _('Error: %s').format(e.message || e)), 'error');
		});
	}
});
