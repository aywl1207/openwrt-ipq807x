# SPDX-License-Identifier: GPL-2.0-only
#
# Enable in seed:
#   CONFIG_PACKAGE_luci-app-wol-api=y
#   CONFIG_PACKAGE_luci-i18n-wol-api-zh-tw=y

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-wol-api
PKG_VERSION:=1.0.3
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Custom

LUCI_TITLE:=WOL API (Home Assistant)
LUCI_DESCRIPTION:=Token-protected Wake-on-LAN HTTP API for Home Assistant / automation.
LUCI_DEPENDS:=+luci-base +etherwake
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)/conffiles
/etc/config/wol_api
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
