#!/bin/bash

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

PATH=$(pwd)/tegraflash:${PATH}

TARGET_TEGRA_VERSION=t210nano;
TARGET_MODULE_ID=3448;
# p3449 is the 4gb devkit carrier, p3452 is the 2gb carrier, but t210 can't read carrier eeprom anyways
TARGET_CARRIER_ID=3449;

source $(pwd)/scripts/helpers.sh;

declare -a FLASH_CMD_EEPROM=(
  --applet nvtboot_recovery.bin
  --chip 0x21);

if ! get_interfaces; then
  exit -1;
fi;

if ! check_compatibility ${TARGET_MODULE_ID} ${TARGET_CARRIER_ID}; then
  echo "No Jetson Nano Devkit found";
  exit -1;
fi;

if [ "${MODULEINFO[version]}" \< "200" ]; then
  echo "Preproduction Jetson Nano revision detected, not supported."
  exit -1;
fi;

BCT_CFG="P3448_A00_lpddr4_204Mhz_P987.cfg"
if [ ${MODULEINFO[sku]} -eq 2 ]; then
  FLASH_XML="flash_android_t210_emmc_p3448.xml"
  if [ "${MODULEINFO[version]}" \< "300" ]; then
    BL_DTB="tegra210-p3448-0002-p3449-0000-a02-android-devkit.dtb"
  else
    BL_DTB="tegra210-p3448-0002-p3449-0000-b00-android-devkit.dtb"
  fi;
elif [ ${MODULEINFO[sku]} -eq 3 ]; then
  FLASH_XML="flash_android_t210_max-spi_sd_p3448.xml"
  BL_DTB="tegra210-p3448-0003-p3542-0000-android.dtb"
elif [ ${MODULEINFO[sku]} -eq 0 ]; then
  FLASH_XML="flash_android_t210_max-spi_sd_p3448.xml"
  if [ "${MODULEINFO[version]}" \< "300" ]; then
    BL_DTB="tegra210-p3448-0000-p3449-0000-a02-android-devkit.dtb"
  else
    BL_DTB="tegra210-p3448-0000-p3449-0000-b00-android-devkit.dtb"
  fi;
else
  echo "Unsupported Nano module sku: ${MODULEINFO[sku]}";
  exit -1;
fi;

# Sign some images
echo "Signing boot images";
cp ${BL_DTB} temp.dtb > /dev/null
cp recovery.img recovery.tmp > /dev/null
cp cboot.bin cboot.tmp > /dev/null
tegraflash.py \
  "${FLASH_CMD_EEPROM[@]}" \
  --bct ${BCT_CFG} \
  --instance ${INTERFACE} \
  --cfg sign.xml \
  --cmd "sign" \
  > /dev/null
cp signed/temp.dtb.encrypt . > /dev/null
cp signed/recovery.tmp.encrypt . > /dev/null
cp signed/cboot.tmp.encrypt . > /dev/null
rm -rf signed temp.dtb recovery.tmp cboot.tmp > /dev/null
truncate -s 589824 cboot.tmp.encrypt

declare -a FLASH_CMD_FLASH=(
  ${FLASH_CMD_EEPROM[@]}
  --bl cboot.tmp.encrypt
  --odmdata 0x94000
  --bct ${BCT_CFG}
  --bldtb temp.dtb.encrypt)

dd if=/dev/zero bs=4096 count=256 of=dummy.bin

tegraflash.py \
  "${FLASH_CMD_FLASH[@]}" \
  --instance ${INTERFACE} \
  --cfg ${FLASH_XML} \
  --cmd "flash; write EBT cboot.tmp.encrypt; reboot"

rm -f temp.dtb.encrypt cboot.tmp.encrypt recovery.tmp.encrypt dummy.bin > /dev/null
