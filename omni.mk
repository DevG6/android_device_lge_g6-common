#
# Copyright (C) 2018 The PureFusionOS Open-Source Project
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

# Inherit from the common Open Source product configuration
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

# The gps config appropriate for this device
$(call inherit-product-if-exists, device/common/gps/gps_us_supl.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/board/generic_arm64/device.mk)
# Inherit from our custom product configuration
$(call inherit-product, vendor/omni/config/common.mk)

 PRODUCT_BRAND := lge
 PRODUCT_MANUFACTURER := LGE

PRODUCT_PACKAGES += \
	adbd

# Boot animation
TARGET_SCREEN_HEIGHT := 2880
TARGET_SCREEN_WIDTH := 1440

$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)


 $(warning *****************************************)
 $(warning Local Path:  $(LOCAL_PATH))
 $(warning *****************************************)
 
 $(info **************************************************)

