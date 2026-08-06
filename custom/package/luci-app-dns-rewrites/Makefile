# SPDX-License-Identifier: GPL-2.0-only
#
# Enable in seed:
#   CONFIG_PACKAGE_luci-app-dns-rewrites=y
#   CONFIG_PACKAGE_luci-i18n-dns-rewrites-zh-tw=y

include $(TOPDIR)/rules.mk

LUCI_TITLE:=DNS Rewrites
LUCI_DESCRIPTION:=Local DNS rewrite UI (private IPv4 or public via upstream DoH).
LUCI_DEPENDS:=+luci-base +dnsmasq
LUCI_PKGARCH:=all

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Custom

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
