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

-include device/nvidia/foster/AndroidBoard.mk

BUILT_TARGET_FILES_ZIPROOT := $(call intermediates-dir-for,PACKAGING,target_files)/$(TARGET_PRODUCT)-target_files
$(BUILT_TARGET_FILES_ZIPROOT).zip: $(BUILT_TARGET_FILES_ZIPROOT)/IMAGES/p3450_flash_package.txz

$(BUILT_TARGET_FILES_ZIPROOT)/IMAGES/p3450_flash_package.txz: $(BUILT_TARGET_FILES_ZIPROOT).zip.list $(PRODUCT_OUT)/p3450_flash_package.txz
	@mkdir -p $(dir $@)
	@cp $(PRODUCT_OUT)/p3450_flash_package.txz $@
	@echo $@ >> $(BUILT_TARGET_FILES_ZIPROOT).zip.list
