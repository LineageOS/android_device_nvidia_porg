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

TEGRAFLASH_PATH := $(BUILD_TOP)/vendor/nvidia/t210/r32/tegraflash
T210_BL         := $(BUILD_TOP)/vendor/nvidia/t210/r32/bootloader
T210_3261_BL    := $(BUILD_TOP)/vendor/nvidia/t210/r32.6.1/bootloader
FOSTER_BCT      := $(BUILD_TOP)/vendor/nvidia/foster/r32/BCT
PORG_FLASH      := $(BUILD_TOP)/device/nvidia/porg/flash_package

INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel

TOYBOX_HOST := $(HOST_OUT_EXECUTABLES)/toybox

INSTALLED_RECOVERYIMAGE_TARGET := $(PRODUCT_OUT)/recovery.img
INSTALLED_TOS_TARGET           := $(PRODUCT_OUT)/tos-mon-only.img

_p3450_package_intermediates := $(call intermediates-dir-for,ETC,p3450_flash_package)
_p3450_package_archive       := $(_p3450_package_intermediates)/p3450_flash_package.txz

include $(CLEAR_VARS)
LOCAL_MODULE       := porg_sd.mtd
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH  := $(PRODUCT_OUT)

_porg_sd_blob_intermediates := $(call intermediates-dir-for,$(LOCAL_MODULE_CLASS),$(LOCAL_MODULE))
_porg_sd_blob := $(_porg_sd_blob_intermediates)/$(LOCAL_MODULE)$(LOCAL_MODULE_SUFFIX)

PORG_SD_SIGNED_PATH := $(_porg_sd_blob_intermediates)
_porg_sd_br_bct     := $(PORG_SD_SIGNED_PATH)/br_bct_BR.bct

BL_TARGETS := \
    cboot.bin \
    tos-mon-only.img
INSTALLED_BL_TARGETS := $(BL_TARGETS:%=$(PRODUCT_OUT)/install/%)
$(INSTALLED_BL_TARGETS): $(_porg_sd_br_bct) | $(ACP)
	@mkdir -p $(PRODUCT_OUT)/install
	cp $(@F:%=$(PORG_SD_SIGNED_PATH)/%.encrypt) $(PRODUCT_OUT)/install/$(notdir $@)

$(_porg_sd_br_bct): $(INSTALLED_RECOVERYIMAGE_TARGET) $(TOYBOX_HOST) $(INSTALLED_KERNEL_TARGET) $(INSTALLED_TOS_TARGET) | $(ACP)
	@mkdir -p $(dir $@)
	@cp $(PORG_FLASH)/flash_android_t210_max-spi_sd_p3448.xml $(dir $@)/flash_android_t210_max-spi_sd_p3448.xml.tmp
	@cp $(FOSTER_BCT)/P3448_A00_lpddr4_204Mhz_P987.cfg $(dir $@)/
	@cp $(T210_BL)/* $(dir $@)/
	@rm $(dir $@)/cboot.bin
	@cp $(T210_3261_BL)/cboot.bin $(dir $@)/cboot.bin
	@rm $(dir $@)/tos-mon-only.img
	@cp $(INSTALLED_TOS_TARGET) $(dir $@)/
	@cp $(PRODUCT_OUT)/install/tegra210-p3448-0003-p3542-0000-android.dtb $(dir $@)/temp.dtb.encrypt
	@cp $(INSTALLED_RECOVERYIMAGE_TARGET) $(dir $@)/recovery.tmp.encrypt
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegraparser --pt flash_android_t210_max-spi_sd_p3448.xml.tmp
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrahost --chip 0x21 --partitionlayout flash_android_t210_max-spi_sd_p3448.xml.bin --list images_list.xml
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrasign --key None --list images_list.xml --pubkeyhash pub_key.key
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.cfg --chip 0x21
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.bct --chip 0x21 --updatedevparam flash_android_t210_max-spi_sd_p3448.xml.bin
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.bct --chip 0x21 --updateblinfo flash_android_t210_max-spi_sd_p3448.xml.bin --updatesig images_list_signed.xml
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegraparser --pt flash_android_t210_max-spi_sd_p3448.xml.bin --chip 0x21 --updatecustinfo P3448_A00_lpddr4_204Mhz_P987.bct
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegraparser --chip 0x21 --updatecustinfo P3448_A00_lpddr4_204Mhz_P987.bct
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.bct --chip 0x21 --updatefields "Odmdata =0x94800"
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.bct --chip 0x21 --listbct bct_list.xml
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrasign --key None --list bct_list.xml --pubkeyhash pub_key.key
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.bct --chip 0x21 --updatesig bct_list_signed.xml
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrahost --chip 0x21 --partitionlayout flash_android_t210_max-spi_sd_p3448.xml.bin --updatesig images_list_signed.xml
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.bct --chip 0x21 --updatebfsinfo flash_android_t210_max-spi_sd_p3448.xml.bin

$(_porg_sd_blob): $(_porg_sd_br_bct) $(INSTALLED_KERNEL_TARGET) $(TOYBOX_HOST) $(_p3450_package_archive) $(INSTALLED_BL_TARGETS) | $(ACP)
	@mkdir -p $(dir $@)
	@dd if=/dev/zero bs=512 count=8K |$(TOYBOX_HOST) tr "\000" "\377" > $@ # 4MB empty file
	@dd if=$(PORG_SD_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=20 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=64 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=128 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=192 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=256 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=320 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=384 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=448 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/nvtboot.bin.encrypt of=$@ bs=512 seek=512 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/flash_android_t210_max-spi_sd_p3448.xml.bin of=$@ bs=512 seek=896 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/nvtboot.bin.encrypt of=$@ bs=512 seek=1024 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/nvtboot_cpu.bin.encrypt of=$@ bs=512 seek=1408 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/warmboot.bin.encrypt of=$@ bs=512 seek=1664 conv=notrunc
	@dd if=$(PORG_SD_SIGNED_PATH)/sc7entry-firmware.bin.encrypt of=$@ bs=512 seek=1792 conv=notrunc
	@dd if=$(T210_BL)/rp4.blob of=$@ bs=512 seek=2048 conv=notrunc
	@dd if=$(_p3450_package_intermediates)/qspi_bootblob_ver.txt of=$@ bs=512 seek=7936 conv=notrunc
	@dd if=$(_p3450_package_intermediates)/qspi_bootblob_ver.txt of=$@ bs=512 seek=8064 conv=notrunc
	@truncate -s 589824 $(PRODUCT_OUT)/install/cboot.bin

include $(BUILD_SYSTEM)/base_rules.mk

include $(CLEAR_VARS)
LOCAL_MODULE       := porg_emmc.boot0
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH  := $(PRODUCT_OUT)

_porg_emmc_blob_intermediates := $(call intermediates-dir-for,$(LOCAL_MODULE_CLASS),$(LOCAL_MODULE))
_porg_emmc_blob := $(_porg_emmc_blob_intermediates)/$(LOCAL_MODULE)$(LOCAL_MODULE_SUFFIX)

PORG_EMMC_SIGNED_PATH := $(_porg_emmc_blob_intermediates)
_porg_emmc_br_bct     := $(PORG_EMMC_SIGNED_PATH)/br_bct_BR.bct

$(_porg_emmc_br_bct): $(INSTALLED_RECOVERYIMAGE_TARGET) $(TOYBOX_HOST) $(INSTALLED_KERNEL_TARGET) $(INSTALLED_TOS_TARGET) $(_p3450_package_archive) | $(ACP)
	@mkdir -p $(dir $@)
	@cp $(PORG_FLASH)/flash_android_t210_emmc_p3448.xml $(dir $@)/flash_android_t210_emmc_p3448.xml.tmp
	@cp $(FOSTER_BCT)/P3448_A00_lpddr4_204Mhz_P987.cfg $(dir $@)/
	@cp $(T210_BL)/* $(dir $@)/
	@rm $(dir $@)/cboot.bin
	@cp $(T210_3261_BL)/cboot.bin $(dir $@)/cboot.bin
	@rm $(dir $@)/tos-mon-only.img
	@cp $(INSTALLED_TOS_TARGET) $(dir $@)/
	@cp $(PRODUCT_OUT)/install/tegra210-p3448-0000-p3449-0000-b00-android-devkit.dtb $(dir $@)/temp.dtb.encrypt
	@cp $(INSTALLED_RECOVERYIMAGE_TARGET) $(dir $@)/recovery.tmp.encrypt
	@cp $(_p3450_package_intermediates)/emmc_bootblob_ver.txt $(dir $@)/
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegraparser --pt flash_android_t210_emmc_p3448.xml.tmp
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrahost --chip 0x21 --partitionlayout flash_android_t210_emmc_p3448.xml.bin --list images_list.xml
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrasign --key None --list images_list.xml --pubkeyhash pub_key.key
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.cfg --chip 0x21
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.bct --chip 0x21 --updatedevparam flash_android_t210_emmc_p3448.xml.bin
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.bct --chip 0x21 --updateblinfo flash_android_t210_emmc_p3448.xml.bin --updatesig images_list_signed.xml
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegraparser --pt flash_android_t210_emmc_p3448.xml.bin --chip 0x21 --updatecustinfo P3448_A00_lpddr4_204Mhz_P987.bct
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegraparser --chip 0x21 --updatecustinfo P3448_A00_lpddr4_204Mhz_P987.bct
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.bct --chip 0x21 --updatefields "Odmdata =0x94800"
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.bct --chip 0x21 --listbct bct_list.xml
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrasign --key None --list bct_list.xml --pubkeyhash pub_key.key
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.bct --chip 0x21 --updatesig bct_list_signed.xml
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrahost --chip 0x21 --partitionlayout flash_android_t210_emmc_p3448.xml.bin --updatesig images_list_signed.xml
	cd $(dir $@); $(TEGRAFLASH_PATH)/tegrabct --bct P3448_A00_lpddr4_204Mhz_P987.bct --chip 0x21 --updatebfsinfo flash_android_t210_emmc_p3448.xml.bin

$(_porg_emmc_blob): $(_porg_emmc_br_bct) $(INSTALLED_KERNEL_TARGET) $(TOYBOX_HOST) $(INSTALLED_BL_TARGETS) | $(ACP)
	@mkdir -p $(dir $@)
	@dd if=/dev/zero bs=512 count=8K |$(TOYBOX_HOST) tr "\000" "\377" > $@ # 4MB empty file
	@dd if=$(PORG_EMMC_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=20 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=64 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=128 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=192 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=256 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=320 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=384 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/P3448_A00_lpddr4_204Mhz_P987.bct of=$@ bs=512 seek=448 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/nvtboot.bin.encrypt of=$@ bs=512 seek=2048 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/flash_android_t210_emmc_p3448.xml.bin of=$@ bs=512 seek=2560 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/nvtboot_cpu.bin.encrypt of=$@ bs=512 seek=2816 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/warmboot.bin of=$@ bs=512 seek=3200 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/sc7entry-firmware.bin of=$@ bs=512 seek=3456 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/nvtboot.bin.encrypt of=$@ bs=512 seek=4864 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/flash_android_t210_emmc_p3448.xml.bin of=$@ bs=512 seek=5376 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/nvtboot_cpu.bin.encrypt of=$@ bs=512 seek=5632 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/warmboot.bin of=$@ bs=512 seek=6016 conv=notrunc
	@dd if=$(PORG_EMMC_SIGNED_PATH)/sc7entry-firmware.bin of=$@ bs=512 seek=6272 conv=notrunc
	@truncate -s 589824 $(PRODUCT_OUT)/install/cboot.bin

include $(BUILD_SYSTEM)/base_rules.mk

include $(CLEAR_VARS)
LOCAL_MODULE       := porg_emmc.boot1
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH  := $(PRODUCT_OUT)

_porg_emmc_blob2_intermediates := $(call intermediates-dir-for,$(LOCAL_MODULE_CLASS),$(LOCAL_MODULE))
_porg_emmc_blob2 := $(_porg_emmc_blob2_intermediates)/$(LOCAL_MODULE)$(LOCAL_MODULE_SUFFIX)

$(_porg_emmc_blob2): $(TOYBOX_HOST) $(_p3450_package_archive) | $(ACP)
	@mkdir -p $(dir $@)
	@dd if=/dev/zero bs=512 count=8K |$(TOYBOX_HOST) tr "\000" "\377" > $@ # 4MB empty file
	@dd if=$(_p3450_package_intermediates)/emmc_bootblob_ver.txt of=$@ bs=512 seek=7936 conv=notrunc
	@dd if=$(_p3450_package_intermediates)/emmc_bootblob_ver.txt of=$@ bs=512 seek=8064 conv=notrunc

include $(BUILD_SYSTEM)/base_rules.mk

ifeq ($(TARGET_PREBUILT_KERNEL),)
INSTALLED_RADIOIMAGE_TARGET += $(PRODUCT_OUT)/$(notdir $(_porg_sd_blob))
INSTALLED_RADIOIMAGE_TARGET += $(PRODUCT_OUT)/$(notdir $(_porg_emmc_blob))
INSTALLED_RADIOIMAGE_TARGET += $(PRODUCT_OUT)/$(notdir $(_porg_emmc_blob2))
endif
