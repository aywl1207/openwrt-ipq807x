# SPDX-License-Identifier: GPL-2.0-or-later
#
# Vendored from udp-redux/udp-broadcast-relay-redux
# (removed from the official packages feed; seed still selects this package).

include $(TOPDIR)/rules.mk

PKG_NAME:=udp-broadcast-relay-redux
PKG_VERSION:=1.0.20240126
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-or-later
PKG_MAINTAINER:=Custom

include $(INCLUDE_DIR)/package.mk

define Package/udp-broadcast-relay-redux
  SECTION:=net
  CATEGORY:=Network
  TITLE:=UDP broadcast relay across interfaces
  URL:=https://github.com/udp-redux/udp-broadcast-relay-redux
endef

define Package/udp-broadcast-relay-redux/description
  Relays UDP broadcasts between interfaces (e.g. IoT doorbell :20005 to LAN / HA).
endef

define Package/udp-broadcast-relay-redux/conffiles
/etc/config/udp_broadcast_relay_redux
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/main.c $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) \
		-o $(PKG_BUILD_DIR)/udp-broadcast-relay-redux \
		$(PKG_BUILD_DIR)/main.c
endef

define Package/udp-broadcast-relay-redux/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/udp-broadcast-relay-redux $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/udp-broadcast-relay-redux.init $(1)/etc/init.d/udp-broadcast-relay-redux
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/udp_broadcast_relay_redux.config $(1)/etc/config/udp_broadcast_relay_redux
endef

$(eval $(call BuildPackage,udp-broadcast-relay-redux))
