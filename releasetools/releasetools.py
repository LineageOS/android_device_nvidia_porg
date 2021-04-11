# Copyright (C) 2019 The LineageOS Project
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

""" Custom OTA commands for foster devices """

import common
import re
import os

APP_PART     = '/dev/block/by-name/APP'
DTB_PART     = '/dev/block/by-name/DTB'
STAGING_PART = '/dev/block/by-name/USP'
VENDOR_PART  = '/dev/block/by-name/vendor'

PUBLIC_KEY_PATH     = '/sys/devices/7000f800.efuse/7000f800.efuse:efuse-burn/public_key'
FUSED_PATH          = '/sys/devices/7000f800.efuse/7000f800.efuse:efuse-burn/odm_production_mode'

MODE_UNFUSED        = '0x00000000\n'
MODE_FUSED          = '0x00000001\n'

JETSON_BL_VERSION   = '00.00.2018.01-t210-4686ce50'

def FullOTA_PostValidate(info):
  if 'INSTALL/bin/resize2fs_static' in info.input_zip.namelist():
    info.script.AppendExtra('run_program("/tmp/install/bin/resize2fs_static", "' + APP_PART + '");');
    info.script.AppendExtra('run_program("/tmp/install/bin/resize2fs_static", "' + VENDOR_PART + '");');

def FullOTA_Assertions(info):
  if 'RADIO/porg_sd.blob' in info.input_zip.namelist():
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
  android_info = input_zip.read("OTA/android-info.txt").decode('utf-8')
  m = re.search(r"require\s+version-bootloader\s*=\s*(\S+)", android_info)
  if m:
    bootloaders = m.group(1).split("|")
    if "*" not in bootloaders:
      info.script.AssertSomeBootloader(*bootloaders)
    info.metadata["pre-bootloader"] = m.group(1)

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
  info.script.AppendExtra('            ui_print("You fused your Jetson Nano?!? Seriously, why would you do this?");')
  info.script.AppendExtra('            ui_print("You are on your own. The LineageOS Maintainer does not want to hear about this.");')
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
  info.script.AppendExtra('      getprop("ro.hardware") == "porg" || getprop("ro.hardware") == "porg_sd" || getprop("ro.hardware") == "batuu",')
  info.script.AppendExtra('      (')
  info.script.AppendExtra('        ifelse(')
  info.script.AppendExtra('          tegra_check_cboot_version("' + JETSON_BL_VERSION + '"),')
  info.script.AppendExtra('          (')
  info.script.AppendExtra('            ui_print("Correct bootloader already installed for unfused " + getprop(ro.hardware));')
  info.script.AppendExtra('          ),')
  info.script.AppendExtra('          (')
  info.script.AppendExtra('            ui_print("Flashing updated bootloader for unfused " + getprop(ro.hardware));')
  info.script.AppendExtra('            package_extract_file("firmware-update/porg_sd.blob", "' + STAGING_PART + '");')
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
  info.script.AppendExtra('            package_extract_file("firmware-update/porg_emmc.blob", "' + STAGING_PART + '");')
  info.script.AppendExtra('            abort();')
  info.script.AppendExtra('          )')
  info.script.AppendExtra('        );')
  info.script.AppendExtra('        package_extract_file("install/" + tegra_get_dtbname(), "' + DTB_PART + '");')
  info.script.AppendExtra('      )')
  info.script.AppendExtra('    );')

  info.script.AppendExtra('  )')
  info.script.AppendExtra(');')
