#
# Copyright (C) 2020 The LineageOS Project
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

include device/nvidia/foster/BoardConfig.mk

# Assert
TARGET_OTA_ASSERT_DEVICE := porg

# Bootloader versions
TARGET_BOARD_INFO_FILE :=

BOARD_CUSTOM_BOOTIMG    := true
BOARD_CUSTOM_BOOTIMG_MK := device/nvidia/porg/mkbootimg.mk
BOARD_KERNEL_CMDLINE    += sdhci_tegra.en_boot_part_access=1

# Releasetools
TARGET_RELEASETOOLS_EXTENSIONS := device/nvidia/porg/releasetools

TARGET_KERNEL_ADDITIONAL_CONFIG := tegra_android_defconfig_extra

BOARD_VENDOR_SEPOLICY_DIRS += device/nvidia/porg/sepolicy
