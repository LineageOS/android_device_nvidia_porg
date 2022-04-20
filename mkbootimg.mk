#
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
#

LOCAL_PATH := $(call my-dir)

BCT_PATH := $(LOCAL_PATH)/tegraflash

# Relative to $PRODUCT_OUT
TEGRAFLASH_PATH := $(BUILD_TOP)/vendor/nvidia/common/tegraflash
T210_PATH       := $(BUILD_TOP)/vendor/nvidia/t210/bootloader
FOSTER_BCT      := $(BUILD_TOP)/vendor/nvidia/foster/BCT

ifneq ($(TARGET_TEGRA_KERNEL),4.9)
DTB_SUBFOLDER := /nvidia
endif

DTB_PATH := obj/KERNEL_OBJ/arch/arm64/boot/dts$(DTB_SUBFOLDER)


$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES) $(BOOTIMAGE_EXTRA_DEPS) $(INSTALLED_KERNEL_TARGET)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKBOOTIMG) --kernel $(call bootimage-to-kernel,$@) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(dir $@)/boot.tmp
	$(hide )$(call assert-max-image-size,$(dir $@)/boot.tmp,$(call get-bootimage-partition-size,$@,boot))
	$(hide) cp $(FOSTER_BCT)/P3448_A00_lpddr4_204Mhz_P987.cfg $(dir $@)/P3448_A00_lpddr4_204Mhz_P987.cfg
	$(hide) cp $(dir $@)/$(DTB_PATH)/tegra210-p3448-0000-p3449-0000-*-android-devkit.dtb $(dir $@)/
	$(hide) cd $(dir $@); PYTHONDONTWRITEBYTECODE=1 $(TEGRAFLASH_PATH)/tegraflash.py --chip 0x21 --applet $(T210_PATH)/nvtboot_recovery.bin --bct P3448_A00_lpddr4_204Mhz_P987.cfg --cfg $(abspath $(BCT_PATH))/signboot.xml --cmd "sign"
	$(hide) mv $(dir $@)/signed $(dir $@)/signed_boot
	@mkdir -p $(PRODUCT_OUT)/install
	$(hide) cp $(dir $@)/signed_boot/tegra210-p3448-0000-p3449-0000-a02-android-devkit.dtb.encrypt $(dir $@)/install/tegra210-p3448-0000-p3449-0000-a02-android-devkit.dtb
	$(hide) cp $(dir $@)/signed_boot/tegra210-p3448-0000-p3449-0000-b00-android-devkit.dtb.encrypt $(dir $@)/install/tegra210-p3448-0000-p3449-0000-b00-android-devkit.dtb
	$(hide) cp $(dir $@)/signed_boot/boot.tmp.encrypt $@

# Depend on boot.img to prevent tegraflash signing from running simultaneously
$(INSTALLED_RECOVERYIMAGE_TARGET): $(recoveryimage-deps) $(RECOVERYIMAGE_EXTRA_DEPS) $(INSTALLED_BOOTIMAGE_TARGET)
	$(call build-recoveryimage-target, $(dir $@)/recovery.tmp, $(recovery_kernel))
	$(hide) cp $(dir $@)/$(DTB_PATH)/tegra210-p3448-0002-p3449-0000-*-android-devkit.dtb $(dir $@)/
	$(hide) cd $(dir $@); PYTHONDONTWRITEBYTECODE=1 $(TEGRAFLASH_PATH)/tegraflash.py --chip 0x21 --applet $(T210_PATH)/nvtboot_recovery.bin --bct P3448_A00_lpddr4_204Mhz_P987.cfg --cfg $(abspath $(BCT_PATH))/signrecovery.xml --cmd "sign"
	$(hide) mv $(dir $@)/signed $(dir $@)/signed_recovery
	$(hide) cp $(dir $@)/signed_recovery/tegra210-p3448-0002-p3449-0000-a02-android-devkit.dtb.encrypt $(dir $@)/install/tegra210-p3448-0002-p3449-0000-a02-android-devkit.dtb
	$(hide) cp $(dir $@)/signed_recovery/tegra210-p3448-0002-p3449-0000-b00-android-devkit.dtb.encrypt $(dir $@)/install/tegra210-p3448-0002-p3449-0000-b00-android-devkit.dtb
	$(hide) cp $(dir $@)/$(DTB_PATH)/tegra210-p3448-0003-p3542-0000-android.dtb $(dir $@)/
	$(hide) cd $(dir $@); PYTHONDONTWRITEBYTECODE=1 $(TEGRAFLASH_PATH)/tegraflash.py --chip 0x21 --applet $(T210_PATH)/nvtboot_recovery.bin --bct P3448_A00_lpddr4_204Mhz_P987.cfg --cfg $(abspath $(BCT_PATH))/signbatuu.xml --cmd "sign"
	$(hide) mv $(dir $@)/signed $(dir $@)/signed_batuu
	$(hide) cp $(dir $@)/signed_batuu/tegra210-p3448-0003-p3542-0000-android.dtb.encrypt $(dir $@)/install/tegra210-p3448-0003-p3542-0000-android.dtb
	$(hide) cp $(dir $@)/signed_recovery/recovery.tmp.encrypt $@
