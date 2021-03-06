LOCAL_DIR := $(call my-dir)

#Android makefile to build kernel as a part of Android Build
PERL		= perl

ifeq ($(TARGET_PREBUILT_KERNEL),)

KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/arm/boot/zImage-dtb
KERNEL_HEADERS_INSTALL := $(KERNEL_OUT)/usr
KERNEL_MODULES_INSTALL := system
KERNEL_MODULES_OUT := $(TARGET_OUT)/lib/modules
KERNEL_IMG=$(KERNEL_OUT)/arch/arm/boot/Image

DTS_NAMES ?= $(shell $(PERL) -e 'while (<>) {$$a = $$1 if /CONFIG_ARCH_((?:MSM|QSD|MPQ)[a-zA-Z0-9]+)=y/; $$r = $$1 if /CONFIG_MSM_SOC_REV_(?!NONE)(\w+)=y/; $$arch = $$arch.lc("$$a$$r ") if /CONFIG_ARCH_((?:MSM|QSD|MPQ)[a-zA-Z0-9]+)=y/} print $$arch;' $(KERNEL_CONFIG))
KERNEL_USE_OF ?= $(shell $(PERL) -e '$$of = "n"; while (<>) { if (/CONFIG_USE_OF=y/) { $$of = "y"; break; } } print $$of;' $(LOCAL_DIR)/arch/arm/configs/$(KERNEL_DEFCONFIG))

ifeq "$(KERNEL_USE_OF)" "y"
DTS_FILES = $(wildcard $(LOCAL_DIR)/arch/arm/boot/dts/$(DTS_TARGET)/$(DTS_NAME)*.dts)
# DTS_FILES = $(wildcard $(TOP)/kernel/arch/arm/boot/dts/$(DTS_NAME)*.dts)
DTS_FILE = $(lastword $(subst /, ,$(1)))
DTB_FILE = $(addprefix $(KERNEL_OUT)/arch/arm/boot/,$(patsubst %.dts,%.dtb,$(call DTS_FILE,$(1))))
ZIMG_FILE = $(addprefix $(KERNEL_OUT)/arch/arm/boot/,$(patsubst %.dts,%-zImage,$(call DTS_FILE,$(1))))
KERNEL_ZIMG = $(KERNEL_OUT)/arch/arm/boot/zImage
DTC = $(KERNEL_OUT)/scripts/dtc/dtc

define append-dtb
mkdir -p $(KERNEL_OUT)/arch/arm/boot;\
$(foreach DTS_NAME, $(DTS_NAMES), \
   $(foreach d, $(DTS_FILES), \
      $(DTC) -p 1024 -O dtb -o $(call DTB_FILE,$(d)) $(d); \
      cat $(KERNEL_ZIMG) $(call DTB_FILE,$(d)) > $(call ZIMG_FILE,$(d));))
endef
else

define append-dtb
endef
endif

ifeq ($(TARGET_USES_UNCOMPRESSED_KERNEL),true)
$(info Using uncompressed kernel)
TARGET_PREBUILT_KERNEL := $(KERNEL_OUT)/piggy
else
TARGET_PREBUILT_KERNEL := $(TARGET_PREBUILT_INT_KERNEL)
endif

define mv-modules
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`;\
ko=`find $$mpath/kernel -type f -name *.ko`;\
for i in $$ko; do mv $$i $(KERNEL_MODULES_OUT)/; done;\
fi
endef

define clean-module-folder
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`; rm -rf $$mpath;\
fi
endef

# VMware_S
MVPD_MODULES := mvpkm.ko commkm.ko pvtcpkm.ko oektestkm.ko
define rm-mvp-modules
if [ "$(strip $(USES_VMWARE_VIRTUALIZATION))" = "true" ];then\
rm -f $(addprefix $(KERNEL_MODULES_OUT)/,$(MVPD_MODULES));\
fi
endef
# VMware_E

$(KERNEL_OUT):
	mkdir -p $(KERNEL_OUT)


# LGE_CHANGE_S
# porting bootchart2 to android
# # byungchul.park@lge.com 20120620
ifeq ($(INIT_BOOTCHART2),true)
KERNEL_DEFCONFIG_PATH:=$(LOCAL_DIR)/arch/arm/configs/$(KERNEL_DEFCONFIG)
KERNEL_DEFCONFIG_BC2_PATH:=$(LOCAL_DIR)/arch/arm/configs/bc2_$(KERNEL_DEFCONFIG)

bootchart2defconfig:
	cp -f $(KERNEL_DEFCONFIG_PATH) $(KERNEL_DEFCONFIG_BC2_PATH)
	echo "CONFIG_TASKSTATS=y" >> $(KERNEL_DEFCONFIG_BC2_PATH)
	echo "CONFIG_TASK_DELAY_ACCT=y" >> $(KERNEL_DEFCONFIG_BC2_PATH)
	echo "CONFIG_TASK_XACCT=y" >> $(KERNEL_DEFCONFIG_BC2_PATH)
	echo "CONFIG_TASK_IO_ACCOUNTING=y" >> $(KERNEL_DEFCONFIG_BC2_PATH)
	echo "CONFIG_CONNECTOR=y" >> $(KERNEL_DEFCONFIG_BC2_PATH)
	echo "CONFIG_PROC_EVENTS=y" >> $(KERNEL_DEFCONFIG_BC2_PATH)


$(KERNEL_CONFIG): $(KERNEL_OUT) bootchart2defconfig
	$(MAKE) -C $(LOCAL_DIR) O=$(ANDROID_BUILD_TOP)/$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(ANDROID_BUILD_TOP)/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi- bc2_$(KERNEL_DEFCONFIG)
else
# LGE_CHANGE_E

$(KERNEL_CONFIG): $(KERNEL_OUT)
	$(MAKE) -C $(LOCAL_DIR) O=$(ANDROID_BUILD_TOP)/$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(ANDROID_BUILD_TOP)/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi- $(KERNEL_DEFCONFIG)
# VMware_S
ifneq ($(TARGET_BUILD_VARIANT), user)
	echo "CONFIG_CHARGER_FACTORY_MODE=y" >> $(KERNEL_CONFIG)
	echo "CONFIG_MMC_MSM_DEBUGFS=y" >> $(KERNEL_CONFIG)
ifeq ($(strip $(USES_VMWARE_VIRTUALIZATION)), true)
	echo "CONFIG_VMWARE_MVP_DEBUG=y" >> $(KERNEL_CONFIG)
	echo "CONFIG_VMWARE_PVTCP_DEBUG=y" >> $(KERNEL_CONFIG)
endif
endif
# VMware_E

# LGE_CHANGE_S
# porting bootchart2 to android
# byungchul.park@lge.com 20120620
endif
# LGE_CHANGE_E

#[BRCM][WAPI][CHINA]Broadcom chipset yongcan.guo for CHINA WAPI  CONFIG_BRCM_WAPI=y
ifeq ($(TARGET_COUNTRY),CN)
	echo "CONFIG_BRCM_WAPI=y" >> $(KERNEL_CONFIG)
endif

$(KERNEL_OUT)/piggy : $(TARGET_PREBUILT_INT_KERNEL)
	$(hide) gunzip -c $(KERNEL_OUT)/arch/arm/boot/compressed/piggy.gzip > $(KERNEL_OUT)/piggy

$(TARGET_PREBUILT_INT_KERNEL): $(KERNEL_OUT) $(KERNEL_CONFIG) $(KERNEL_HEADERS_INSTALL)
	$(MAKE) -C $(LOCAL_DIR) O=$(ANDROID_BUILD_TOP)/$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(ANDROID_BUILD_TOP)/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi-

ifeq ($(PRODUCT_SUPPORT_EXFAT), y)
	@cp -f $(ANDROID_BUILD_TOP)/kernel/lge/g3/tuxera_update.sh $(ANDROID_BUILD_TOP)
	@sh tuxera_update.sh --target target/lg.d/mobile-mtp-3013.6.27 --use-cache --latest --max-cache-entries 2 --source-dir $(ANDROID_BUILD_TOP)/kernel/lge/g3 --output-dir $(ANDROID_BUILD_TOP)/$(KERNEL_OUT) -a --user lg-mobile --pass AumlTsj0ou
	@tar -xzf tuxera-exfat*.tgz
	@mkdir -p $(TARGET_OUT_EXECUTABLES)
	@cp $(ANDROID_BUILD_TOP)/tuxera-exfat*/exfat/kernel-module/texfat.ko $(ANDROID_BUILD_TOP)/$(TARGET_OUT_EXECUTABLES)/../lib/modules/
	@cp $(ANDROID_BUILD_TOP)/tuxera-exfat*/exfat/tools/* $(TARGET_OUT_EXECUTABLES)
	@rm -f kheaders*.tar.bz2
	@rm -f tuxera-exfat*.tgz
	@rm -rf tuxera-exfat*
	@rm -f tuxera_update.sh
endif

# VMware_S
	$(rm-mvp-modules)
# VMware_E
	$(append-dtb)

$(KERNEL_HEADERS_INSTALL): $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C $(LOCAL_DIR) O=$(ANDROID_BUILD_TOP)/$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(ANDROID_BUILD_TOP)/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi- headers_install

kerneltags: $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C $(LOCAL_DIR) O=$(ANDROID_BUILD_TOP)/$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(ANDROID_BUILD_TOP)/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi- tags

kernelconfig: $(KERNEL_OUT) $(KERNEL_CONFIG)
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C $(LOCAL_DIR) O=$(ANDROID_BUILD_TOP)/$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(ANDROID_BUILD_TOP)/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi- menuconfig
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C $(LOCAL_DIR) O=$(ANDROID_BUILD_TOP)/$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(ANDROID_BUILD_TOP)/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi- savedefconfig
	cp $(KERNEL_OUT)/defconfig $(LOCAL_DIR)/arch/arm/configs/$(KERNEL_DEFCONFIG)

endif
