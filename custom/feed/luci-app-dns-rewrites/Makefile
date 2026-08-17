# SPDX-License-Identifier: GPL-2.0-only
#
# Enable in seed:
#   CONFIG_PACKAGE_luci-app-dns-rewrites=y
#   CONFIG_PACKAGE_luci-i18n-dns-rewrites-zh-tw=y

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-dns-rewrites
PKG_VERSION:=1.1.8
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Custom

LUCI_TITLE:=DNS Custom Rewrites
LUCI_DESCRIPTION:=Local custom DNS rewrite UI (private IPv4 or public via upstream DoH).
LUCI_DEPENDS:=+luci-base +dnsmasq
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)/conffiles
/etc/config/dns_rewrite
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
