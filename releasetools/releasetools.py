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

""" Custom OTA commands for porg devices """

import common
import re
import os

APP_PART     = '/dev/block/by-name/APP'
BOOT0_PART   = '/dev/block/mmcblk0boot0'
BOOT1_PART   = '/dev/block/mmcblk0boot1'
EBT_PART     = '/dev/block/by-name/EBT'
EBT_BAK_PART = '/dev/block/by-name/EBT-1'
DTB_PART     = '/dev/block/by-name/DTB'
DTB_BAK_PART = '/dev/block/by-name/DTB-1'
MTD_PART     = '/dev/block/mtdblock0'
RP1_PART     = '/dev/block/by-name/RP1'
RP1_BAK_PART = '/dev/block/by-name/RP1-1'
TOS_PART     = '/dev/block/by-name/TOS'
TOS_BAK_PART = '/dev/block/by-name/TOS-1'
VENDOR_PART  = '/dev/block/by-name/vendor'

PUBLIC_KEY_PATH     = '/sys/devices/7000f800.efuse/7000f800.efuse:efuse-burn/public_key'
FUSED_PATH          = '/sys/devices/7000f800.efuse/7000f800.efuse:efuse-burn/odm_production_mode'

MODE_UNFUSED        = '0x00000000\n'
MODE_FUSED          = '0x00000001\n'

JETSON_BL_VERSION   = '00.00.2018.01-t210-c952b4e6'

def FullOTA_PostValidate(info):
  if 'INSTALL/bin/resize2fs_static' in info.input_zip.namelist():
    info.script.AppendExtra('run_program("/tmp/install/bin/resize2fs_static", "' + APP_PART + '");');
    info.script.AppendExtra('run_program("/tmp/install/bin/resize2fs_static", "' + VENDOR_PART + '");');

def FullOTA_Assertions(info):
  if 'RADIO/porg_sd.mtd' in info.input_zip.namelist():
    CopyBlobs(info.input_zip, info.output_zip)
    AddBootloaderFlash(info, info.input_zip)
  else:
    AddBootloaderAssertion(info, info.input_zip)

def IncrementalOTA_Assertions(info):
  FullOTA_Assertions(info)

def CopyBlobs(input_zip, output_zip):
  for info in input_zip.infolist():
    f = info.filename
    if f.startswith("RADIO/") and (f.__len__() > len("RADIO/")):
      fn = f[6:]
      common.ZipWriteStr(output_zip, "firmware-update/" + fn, input_zip.read(f))

def AddBootloaderAssertion(info, input_zip):
  info.script.AppendExtra('ifelse(')
  info.script.AppendExtra('  getprop("ro.hardware") == "porg" || getprop("ro.hardware") == "porg_sd" || getprop("ro.hardware") == "batuu",')
  info.script.AppendExtra('  (')
  info.script.AppendExtra('    ifelse(')
  info.script.AppendExtra('      tegra_check_cboot_version("' + JETSON_BL_VERSION + '"),')
  info.script.AppendExtra('      (')
  info.script.AppendExtra('        ui_print("Correct bootloader already installed for fused " + getprop(ro.hardware));')
  info.script.AppendExtra('      ),')
  info.script.AppendExtra('      (')
  info.script.AppendExtra('        ui_print("Incorrect bootloader detected, but cannot update to correct version.");')
  info.script.AppendExtra('        abort();')
  info.script.AppendExtra('      )')
  info.script.AppendExtra('    );')
  info.script.AppendExtra('    package_extract_file("install/" + tegra_get_dtbname(), "' + DTB_PART + '");')
  info.script.AppendExtra('  )')
  info.script.AppendExtra(');')

def AddBootloaderFlash(info, input_zip):
  """ If device is fused """
  info.script.AppendExtra('ifelse(')
  info.script.AppendExtra('  read_file("' + FUSED_PATH + '") == "' + MODE_FUSED + '",')
  info.script.AppendExtra('  (')

  """ Fused porg """
  info.script.AppendExtra('    ifelse(')
  info.script.AppendExtra('      getprop("ro.hardware") == "porg" || getprop("ro.hardware") == "porg_sd" || getprop("ro.hardware") == "batuu",')
  info.script.AppendExtra('      (')
  info.script.AppendExtra('        ifelse(')
  info.script.AppendExtra('          tegra_check_cboot_version("' + JETSON_BL_VERSION + '"),')
  info.script.AppendExtra('          (')
  info.script.AppendExtra('            ui_print("Correct bootloader already installed for fused " + getprop(ro.hardware));')
  info.script.AppendExtra('          ),')
  info.script.AppendExtra('          (')
  info.script.AppendExtra('            ui_print("Incorrect bootloader detected, but cannot update to correct version.");')
  info.script.AppendExtra('            abort();')
  info.script.AppendExtra('          )')
  info.script.AppendExtra('        );')
  info.script.AppendExtra('        package_extract_file("install/" + tegra_get_dtbname(), "' + DTB_PART + '");')
  info.script.AppendExtra('      )')
  info.script.AppendExtra('    );')

  info.script.AppendExtra('  ),')

  """ If not fused """
  info.script.AppendExtra('  (')

  """ Unfused porg_sd/batuu """
  info.script.AppendExtra('    ifelse(')
  info.script.AppendExtra('      getprop("ro.hardware") == "porg_sd" || getprop("ro.hardware") == "batuu",')
  info.script.AppendExtra('      (')
  info.script.AppendExtra('        ifelse(')
  info.script.AppendExtra('          tegra_check_cboot_version("' + JETSON_BL_VERSION + '"),')
  info.script.AppendExtra('          (')
  info.script.AppendExtra('            ui_print("Correct bootloader already installed for unfused " + getprop(ro.hardware));')
  info.script.AppendExtra('          ),')
  info.script.AppendExtra('          (')
  info.script.AppendExtra('            ui_print("Flashing updated bootloader for unfused " + getprop(ro.hardware));')
  info.script.AppendExtra('            package_extract_file("firmware-update/porg_sd.mtd", "' + MTD_PART + '");')
  info.script.AppendExtra('            package_extract_file("install/" + tegra_get_dtbname(), "' + RP1_PART + '");')
  info.script.AppendExtra('            package_extract_file("install/cboot.bin", "' + EBT_PART + '");')
  info.script.AppendExtra('            package_extract_file("install/tos-mon-only.img", "' + TOS_PART + '");')
  info.script.AppendExtra('          )')
  info.script.AppendExtra('        );')
  info.script.AppendExtra('        package_extract_file("install/" + tegra_get_dtbname(), "' + DTB_PART + '");')
  info.script.AppendExtra('      )')
  info.script.AppendExtra('    );')

  """ Unfused porg """
  info.script.AppendExtra('    ifelse(')
  info.script.AppendExtra('      getprop("ro.hardware") == "porg",')
  info.script.AppendExtra('      (')
  info.script.AppendExtra('        ifelse(')
  info.script.AppendExtra('          tegra_check_cboot_version("' + JETSON_BL_VERSION + '"),')
  info.script.AppendExtra('          (')
  info.script.AppendExtra('            ui_print("Correct bootloader already installed for unfused " + getprop(ro.hardware));')
  info.script.AppendExtra('          ),')
  info.script.AppendExtra('          (')
  info.script.AppendExtra('            ui_print("Flashing updated bootloader for unfused " + getprop(ro.hardware));')
  info.script.AppendExtra('            package_extract_file("firmware-update/porg_emmc.boot0", "' + BOOT0_PART + '");')
  info.script.AppendExtra('            package_extract_file("firmware-update/porg_emmc.boot1", "' + BOOT1_PART + '");')
  info.script.AppendExtra('            package_extract_file("install/" + tegra_get_dtbname(), "' + RP1_PART + '");')
  info.script.AppendExtra('            package_extract_file("install/" + tegra_get_dtbname(), "' + RP1_BAK_PART + '");')
  info.script.AppendExtra('            package_extract_file("install/cboot.bin", "' + EBT_PART + '");')
  info.script.AppendExtra('            package_extract_file("install/cboot.bin", "' + EBT_BAK_PART + '");')
  info.script.AppendExtra('            package_extract_file("install/tos-mon-only.img", "' + TOS_PART + '");')
  info.script.AppendExtra('            package_extract_file("install/tos-mon-only.img", "' + TOS_BAK_PART + '");')
  info.script.AppendExtra('            abort();')
  info.script.AppendExtra('          )')
  info.script.AppendExtra('        );')
  info.script.AppendExtra('        package_extract_file("install/" + tegra_get_dtbname(), "' + DTB_PART + '");')
  info.script.AppendExtra('        package_extract_file("install/" + tegra_get_dtbname(), "' + DTB_BAK_PART + '");')
  info.script.AppendExtra('      )')
  info.script.AppendExtra('    );')

  info.script.AppendExtra('  )')
  info.script.AppendExtra(');')
