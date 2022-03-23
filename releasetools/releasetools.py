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
DTB_PART     = '/dev/block/by-name/DTB'
VENDOR_PART  = '/dev/block/by-name/vendor'

PUBLIC_KEY_PATH     = '/sys/devices/7000f800.efuse/7000f800.efuse:efuse-burn/public_key'
FUSED_PATH          = '/sys/devices/7000f800.efuse/7000f800.efuse:efuse-burn/odm_production_mode'

JETSON_BL_VERSION   = '00.00.2018.01-t210-a2f2e4b8'

def FullOTA_PostValidate(info):
  if 'INSTALL/bin/resize2fs_static' in info.input_zip.namelist():
    info.script.AppendExtra('run_program("/tmp/install/bin/resize2fs_static", "' + APP_PART + '");');
    info.script.AppendExtra('run_program("/tmp/install/bin/resize2fs_static", "' + VENDOR_PART + '");');

  AddBootloaderAssertion(info, info.input_zip)

def IncrementalOTA_Assertions(info):
  FullOTA_Assertions(info)

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
