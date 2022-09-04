# Copyright (C) 2021 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

LOCAL_PATH := $(call my-dir)

TEGRAFLASH_PATH := $(BUILD_TOP)/vendor/nvidia/common/tegraflash
T210_BL         := $(BUILD_TOP)/vendor/nvidia/t210/bootloader
PORG_BL         := $(BUILD_TOP)/vendor/nvidia/porg/bootloader
FOSTER_BCT      := $(BUILD_TOP)/vendor/nvidia/foster/BCT
PORG_FLASH      := $(BUILD_TOP)/device/nvidia/porg/flash_package
COMMON_FLASH    := $(BUILD_TOP)/device/nvidia/tegra-common/flash_package

INSTALLED_BMP_BLOB_TARGET      := $(PRODUCT_OUT)/bmp.blob
INSTALLED_KERNEL_TARGET        := $(PRODUCT_OUT)/kernel
INSTALLED_RECOVERYIMAGE_TARGET := $(PRODUCT_OUT)/recovery.img

TOYBOX_HOST  := $(HOST_OUT_EXECUTABLES)/toybox
AWK_HOST     := $(HOST_OUT_EXECUTABLES)/one-true-awk

include $(CLEAR_VARS)
LOCAL_MODULE        := p3450_flash_package
LOCAL_MODULE_SUFFIX := .txz
LOCAL_MODULE_CLASS  := ETC
LOCAL_MODULE_PATH   := $(PRODUCT_OUT)

_p3450_package_intermediates := $(call intermediates-dir-for,$(LOCAL_MODULE_CLASS),$(LOCAL_MODULE))
_p3450_package_archive := $(_p3450_package_intermediates)/$(LOCAL_MODULE)$(LOCAL_MODULE_SUFFIX)

$(_p3450_package_archive): $(INSTALLED_BMP_BLOB_TARGET) $(INSTALLED_KERNEL_TARGET) $(INSTALLED_RECOVERYIMAGE_TARGET) $(AWK_HOST) $(TOYBOX_HOST)
	@rm -fv $(_p3450_package_archive)
	@mkdir -p $(dir $@)/tegraflash
	@mkdir -p $(dir $@)/scripts
	@cp $(TEGRAFLASH_PATH)/tegra* $(dir $@)/tegraflash/
	@rm $(dir $@)/tegraflash/*_v2
	@cp $(COMMON_FLASH)/*.sh $(dir $@)/scripts/
	@cp $(PORG_FLASH)/p3450.sh $(dir $@)/flash.sh
	@cp $(PORG_FLASH)/flash_android_t210_emmc_p3448.xml $(dir $@)/
	@cp $(PORG_FLASH)/flash_android_t210_max-spi_sd_p3448.xml $(dir $@)/
	@cp $(PORG_FLASH)/sign.xml $(dir $@)/
	@cp $(T210_BL)/* $(dir $@)/
	@cp $(INSTALLED_BMP_BLOB_TARGET) $(dir $@)/
	@cp $(INSTALLED_RECOVERYIMAGE_TARGET) $(dir $@)/
	@cp $(KERNEL_OUT)/arch/arm64/boot/dts/tegra210-p3448-*-p3449-0000-*-android-devkit.dtb $(dir $@)/
	@cp $(KERNEL_OUT)/arch/arm64/boot/dts/tegra210-p3448-0003-p3542-0000-android.dtb $(dir $@)/
	@cp $(FOSTER_BCT)/P3448_A00_lpddr4_204Mhz_P987.cfg $(dir $@)/
	@echo "NV3" > $(dir $@)/emmc_bootblob_ver.txt
	@echo "# R18 , REVISION: 1" >> $(dir $@)/emmc_bootblob_ver.txt
	@echo "BOARDID=3448 BOARDSKU=0002 FAB=200" >> $(dir $@)/emmc_bootblob_ver.txt
	@$(TOYBOX_HOST) date '+%Y%m%d%H%M%S' >> $(dir $@)/emmc_bootblob_ver.txt
	@$(TOYBOX_HOST) cksum $(dir $@)/emmc_bootblob_ver.txt |$(AWK_HOST) '{ print "BYTES:" $$2, "CRC32:" $$1 }' >> $(dir $@)/emmc_bootblob_ver.txt
	@echo "NV3" > $(dir $@)/qspi_bootblob_ver.txt
	@echo "# R18 , REVISION: 1" >> $(dir $@)/qspi_bootblob_ver.txt
	@echo "BOARDID=3448 BOARDSKU=0000 FAB=200" >> $(dir $@)/qspi_bootblob_ver.txt
	@$(TOYBOX_HOST) date '+%Y%m%d%H%M%S' >> $(dir $@)/qspi_bootblob_ver.txt
	@$(TOYBOX_HOST) cksum $(dir $@)/qspi_bootblob_ver.txt |$(AWK_HOST) '{ print "BYTES:" $$2, "CRC32:" $$1 }' >> $(dir $@)/qspi_bootblob_ver.txt
	@cd $(dir $@); tar -cJf $(abspath $@) *

include $(BUILD_SYSTEM)/base_rules.mk
