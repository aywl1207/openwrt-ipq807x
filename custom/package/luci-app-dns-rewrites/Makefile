# SPDX-License-Identifier: GPL-2.0-only
#
# luci-app-dns-rewrites — LuCI + helper for stable dnsmasq rewrites
# Enable: CONFIG_PACKAGE_luci-app-dns-rewrites=y  (seed)

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-dns-rewrites
PKG_VERSION:=1.0.0
PKG_RELEASE:=2

PKG_MAINTAINER:=Custom
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-dns-rewrites
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=DNS Rewrites
  DEPENDS:=+luci-base +dnsmasq
  PKGARCH:=all
endef

define Package/luci-app-dns-rewrites/description
  Web UI and apply helper for local DNS rewrites:
  private fixed IPv4 (address=/… + local=) or public via upstream DoH
  (server=/…/127.0.0.1#5053). Avoids cname under partial local zones.
endef

define Package/luci-app-dns-rewrites/conffiles
/etc/config/dns_rewrite
endef

define Package/luci-app-dns-rewrites/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/dns-rewrite-apply $(1)/usr/sbin/dns-rewrite-apply

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/dns-rewrite.init $(1)/etc/init.d/dns-rewrite

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/95-dns-rewrites $(1)/etc/uci-defaults/95-dns-rewrites

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/dns_rewrite.config $(1)/etc/config/dns_rewrite

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./files/luci-app-dns-rewrites.json $(1)/usr/share/luci/menu.d/

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/luci-app-dns-rewrites-acl.json $(1)/usr/share/rpcd/acl.d/luci-app-dns-rewrites.json

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/dns-rewrites
	$(INSTALL_DATA) ./files/rewrites.js $(1)/www/luci-static/resources/view/dns-rewrites/rewrites.js
endef

define Package/luci-app-dns-rewrites/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/dns-rewrite enable 2>/dev/null || true
	/etc/init.d/rpcd restart 2>/dev/null || true
	/etc/init.d/uhttpd restart 2>/dev/null || true
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-dns-rewrites))
