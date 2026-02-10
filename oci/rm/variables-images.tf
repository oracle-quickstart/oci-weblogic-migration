# Copyright (c) 2026, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl


locals{
  marketplace_images_map={
    # Liting_ids and marketplace related variables are pre populated based on the discovered OS.
    ee-byol = {
      listing_id = var.byol_listing_id,
      listing_resource_version= var.byol_listing_resource_version,
      instance_image_id = var.byol_instance_image_id
      agreement_needed = true
    }
    suite-byol = {
      listing_id = var.suite_byol_listing_id,
      listing_resource_version= var.suite_byol_listing_resource_version,
      instance_image_id = var.suite_byol_instance_image_id
      agreement_needed = true
    }
    ee-ucm = {
      listing_id = var.ucm_listing_id,
      listing_resource_version= var.ucm_listing_resource_version,
      instance_image_id = var.ucm_instance_image_id
      agreement_needed = true
    }
    suite-ucm = {
      listing_id = var.suite_ucm_listing_id,
      listing_resource_version= var.suite_ucm_listing_resource_version,
      instance_image_id = var.suite_ucm_instance_image_id
      agreement_needed = true
    }
    custom = {
      instance_image_id = var.wlsserver_image_custom_id
      agreement_needed = false
      vm_scripts_path = var.wlsoci_vmscripts_zip_bundle_path
    }
    platform = {
      instance_image_id = var.wlsserver_image_platform_id[var.region]
      agreement_needed = false
      vm_scripts_path = var.wlsoci_vmscripts_zip_bundle_path
    }
  }

  marketplace_images_schema_map = zipmap(
    ["Oracle WebLogic Server Enterprise Edition UCM Image", "Oracle Weblogic Suite UCM Image", "Oracle WebLogic Server Enterprise Edition BYOL Image", "Oracle Weblogic Suite BYOL Image", "custom", "Platform Image"],
    ["ee-ucm", "suite-ucm", "ee-byol", "suite-byol", "custom", "platform"]
  )

  terms_and_conditions_map = {
    ee-byol    = var.terms_and_conditions_byol
    suite-byol = var.terms_and_conditions_byol
    ee-ucm     = var.terms_and_conditions_ee_ucm
    suite-ucm  = var.terms_and_conditions_suite_ucm
  }

  image_type_selected_key          = local.marketplace_images_schema_map[var.wlsserver_image_type]
  vm_instance_image_id  = lookup(local.marketplace_images_map[local.image_type_selected_key],"instance_image_id","ohhh")
  listing_id_selected = lookup(local.marketplace_images_map[local.image_type_selected_key],"listing_id", "none")
  listing_resource_version_selected = lookup(local.marketplace_images_map[local.image_type_selected_key],"listing_resource_version","none")
  vm_scripts_path_selected = lookup(local.marketplace_images_map[local.image_type_selected_key],"vm_scripts_path", null )

  vm_instance_image_requirements = {
    tnc = lookup(
      local.terms_and_conditions_map,
      local.image_type_selected_key,
      false
    )
    agreement = lookup(local.marketplace_images_map[local.image_type_selected_key],"agreement_needed", false)
  }

  #  wlsserver_image_id   =  var.use_marketplace_image ? local.vm_instance_image_id: coalesce(var.wlsserver_image_custom_id, var.wlsserver_image_platform_id, "none")
  #  wlsserver_image_type = contains(["custom"], lower(var.wlsserver_image_type)) ? "custom" : contains(["Oracle WebLogic Server BYOL"], lower(var.wlsserver_image_type)) ? "ucm-ee":"ucm-suite"
  wlsserver_image_type =  lookup(local.marketplace_images_schema_map,var.wlsserver_image_type,null)
}

/*
* Oracle-provided OL 8.10 image = Oracle-Linux-8.10-2025.06.17-0
*
* Also see https://docs.oracle.com/en-us/iaas/images/ to pick another image in future.
*/
variable "wlsserver_image_platform_id" {
  type = map(any)
  default = {
    af-johannesburg-1 = "ocid1.image.oc1.af-johannesburg-1.aaaaaaaay5j4j5bvem57hgdtgsykxh6m34ypyjy2qaksaxpbxvgpnd3w74fq"
    ap-chuncheon-1    = "ocid1.image.oc1.ap-chuncheon-1.aaaaaaaalnj3p2othb7ol3fzt32zmdudmvo63frmzgm7uryu7xjpo2fqrjja"
    ap-hyderabad-1    = "ocid1.image.oc1.ap-hyderabad-1.aaaaaaaavaggear4d26sxqntazzrsosqb63nm6ym6ubg6ttbwt7yjgrws63q"
    ap-melbourne-1    = "ocid1.image.oc1.ap-melbourne-1.aaaaaaaajfy73akmzspkidlfpwgfdcs6y5unpwylhzvhsfptxdrhtpuvvooa"
    ap-mumbai-1       = "ocid1.image.oc1.ap-mumbai-1.aaaaaaaagazuoww5zv6ol2xdrtjxxis6smneacbnrsguheclgawgkpxcau7a"
    ap-osaka-1        = "ocid1.image.oc1.ap-osaka-1.aaaaaaaakanyhjqudl3gc5fuqln2afmcajgddkcdu63yc3zre7ffcbnu2iqa"
    ap-seoul-1        = "ocid1.image.oc1.ap-seoul-1.aaaaaaaabldx6hxu5ckj6e4iabsb3abtp2cisybj6ta74u76fiiidkdoemuq"
    ap-singapore-1    = "ocid1.image.oc1.ap-singapore-1.aaaaaaaainwlb44igcu7vsrpyipsk2tcr2cn2oxcr7fmfxvz75fpazvl5gba"
    ap-sydney-1       = "ocid1.image.oc1.ap-sydney-1.aaaaaaaa6junrfvgz4w2hxrgsk657l7i2xwx6lcwg37vom4hvtftgtob55la"
    ap-tokyo-1        = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaaofxejujzlccmzvjhxxm2zp76v3ijo7rfjoiwoomkvnai4ypsyrzq"
    ca-montreal-1     = "ocid1.image.oc1.ca-montreal-1.aaaaaaaab2kus5fs6dpekut4d37yodlkf5larzinpvamxow74vgfyiaxw3fa"
    ca-toronto-1      = "ocid1.image.oc1.ca-toronto-1.aaaaaaaa2im7geo2sn2sdylcemhe43452adn55is3lsobdja4unpk6zlbs7a"
    eu-amsterdam-1    = "ocid1.image.oc1.eu-amsterdam-1.aaaaaaaamrht66b6zcl7vzs7djojqaami432xktrex26k5m753ogp5ltbsva"
    eu-frankfurt-1    = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaarkbzaibauusikht7yz7smu4svvcytyrmbuud3bywibktwlfxf23a"
    eu-madrid-1       = "ocid1.image.oc1.eu-madrid-1.aaaaaaaasltmyjre7w2c2ipv2nyi4ou4rumcb6lqy2wi6nh5tdfcggbvt7mq"
    eu-marseille-1    = "ocid1.image.oc1.eu-marseille-1.aaaaaaaaab7cwzl2mvs3yoz2pyi2mipfujzyec3tbi4ufqntuf42ckmung7q"
    eu-milan-1        = "ocid1.image.oc1.eu-milan-1.aaaaaaaaoiz2rokyyv6deqya6ywasym2c3rvk3opzbsyvcpcv7tgz4hjhmfq"
    eu-paris-1        = "ocid1.image.oc1.eu-paris-1.aaaaaaaarj6zpnkzvbipovytohdvztb4kgszpfuw7c4qnst5zei24trh5qoq"
    eu-stockholm-1    = "ocid1.image.oc1.eu-stockholm-1.aaaaaaaa2fn7sqjisl35jwhxpklro6qxxoq3waswwip3hg3iwaj7jt7egusq"
    eu-zurich-1       = "ocid1.image.oc1.eu-zurich-1.aaaaaaaauzdi3dh23wxzn3wccmio3uaqc54knmric72n35g5xfxs4vucvvca"
    il-jerusalem-1    = "ocid1.image.oc1.il-jerusalem-1.aaaaaaaacwx6xvqt2gbsp276kawilw5m6wbqblntijtikewj6gva2m64hh3q"
    me-abudhabi-1     = "ocid1.image.oc1.me-abudhabi-1.aaaaaaaaarsrpgvcr2fxzif2jvzbjrkwtkustwc4atxoyucepr7e34bptbaq"
    me-dubai-1        = "ocid1.image.oc1.me-dubai-1.aaaaaaaad3c4ydnwjbkike7us5r5ezf4q7cg2ur7y5ilbv6oxcnrogbnntpa"
    me-jeddah-1       = "ocid1.image.oc1.me-jeddah-1.aaaaaaaau3qqxkxi2uvgfqqxw34cbqtxslf4m5k5uufq2ohszb7tte7t3asq"
    mx-monterrey-1    = "ocid1.image.oc1.mx-monterrey-1.aaaaaaaaeaj65pedyvvgpsr4aieydbqkqnfg3v4odu3i7rhrxjkzafhdd2qq"
    mx-queretaro-1    = "ocid1.image.oc1.mx-queretaro-1.aaaaaaaamvbr7x3d4ygu7jbnzxzh2lh6uquxhxzz6dlgfgoniwfgjpzmi35a"
    sa-bogota-1       = "ocid1.image.oc1.sa-bogota-1.aaaaaaaaca3yio3mrilk2fnlmkdfdwigtgbvt2usxuontmdqxce5gsclhhma"
    sa-santiago-1     = "ocid1.image.oc1.sa-santiago-1.aaaaaaaa4shxfvkoiq6di5bmq3e6eeqbcym4gkamcux7c7z3fb6oinum4rza"
    sa-saopaulo-1     = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaao2gthd6o5fagrhypz44hcs6oj2x673npqhkjuivhgovckbu2tj4a"
    sa-valparaiso-1   = "ocid1.image.oc1.sa-valparaiso-1.aaaaaaaazf3pmmral7qpmdvmfbmqliusbaiuf3l6lo233ycar4mp5iqvgiya"
    uk-cardiff-1      = "ocid1.image.oc1.uk-cardiff-1.aaaaaaaagvbbbvmudz7k7ja6m6bcuulbla26kw354qzajl2ifqtuy72pbu7a"
    uk-london-1       = "ocid1.image.oc1.uk-london-1.aaaaaaaam5klmkoewhybytfqlkyhcoxyzjxstx6emfk5dop7f2bazqopi5nq"
    us-ashburn-1      = "ocid1.image.oc1.iad.aaaaaaaavzb4qckh7yjuszdlgxtl4zduttgdig5ybpoc5ncsiekjkxkqzakq"
    us-chicago-1      = "ocid1.image.oc1.us-chicago-1.aaaaaaaatabstkchlofmhhmmld7mpmwdqdo3ymmvcwavsee7hoogekxdyjsq"
    us-phoenix-1      = "ocid1.image.oc1.phx.aaaaaaaao5utguwhdajyvlkslqbudz4l6jhctwrcntax7ol3ouvjnfqhspna"
    us-sanjose-1      = "ocid1.image.oc1.us-sanjose-1.aaaaaaaapwh35l2k4eqtw36jvgovzq3dcoriouefwsv2jj6gomndbs5o3daa"
  }
}

variable "wlsserver_image_custom_id" {
  default = null
  type    = string
}

variable "byol_instance_image_id" {
  type        = string
  description = "The OCID of the compute image used to create the WebLogic compute instances"
}

variable "suite_byol_instance_image_id" {
  type        = string
  description = "The OCID of the compute image used to create the WebLogic compute instances"
}

variable "use_bastion_marketplace_image" {
  type        = bool
  description = "Set to true if using a marketplace bastion image, to create the marketplace subscriptions"
  default     = true
}

variable "bastion_image_id" {
  type        = string
  description = "The OCID of the marketplace bastion image"
  default     = "ocid1.image.oc1..aaaaaaaablqmvpn633emdv7o2k42km6nxjt4i44aqwab3wxwquyz3ag6hvmq"
}

variable "bastion_listing_id" {
  type        = string
  description = "The OCID of the marketplace bastion image listing"
  default     = "ocid1.appcataloglisting.oc1..aaaaaaaacicjx6jviqczqow567tadr5ju7iy2m4vx6opyra6thql55n2nnvq"
}

variable "bastion_listing_resource_version" {
  type        = string
  description = "The OCID of the marketplace bastion image listing resource version"
  default     = "23.2.3-ol8.7-23.04.25-230702-1"
}

variable "use_marketplace_image" {
  type        = bool
  description = "Set to true if using a marketplace WebLogic instance image, to create the marketplace subscriptions"
  default     = true
}

variable "byol_listing_id" {
  type        = string
  description = "The OCID of the marketplace BYOL image listing"
}

variable "byol_listing_resource_version" {
  type        = string
  description = "The OCID of the marketplace BYOL image listing resource version"
}

variable "suite_byol_listing_id" {
  type        = string
  description = "The OCID of the marketplace BYOL image listing"
}

variable "suite_byol_listing_resource_version" {
  type        = string
  description = "The OCID of the marketplace BYOL image listing resource version"
}

variable "ucm_instance_image_id" {
  type        = string
  description = "The OCID of the marketplace Enterprise Edition UCM image which is used for provisioning"
}

variable "ucm_listing_id" {
  type        = string
  description = "The OCID of the marketplace Enterprise Edition UCM image listing"
}

variable "ucm_listing_resource_version" {
  type        = string
  description = "The OCID of the marketplace Enterprise Edition UCM image listing resource version"
}

variable "suite_ucm_instance_image_id" {
  type        = string
  description = "The OCID of the marketplace Suite UCM image which is used for provisioning"
}

variable "suite_ucm_listing_id" {
  type        = string
  description = "The OCID of the marketplace Suite UCM image listing"
}

variable "suite_ucm_listing_resource_version" {
  type        = string
  description = "The OCID of the marketplace Suite UCM image listing resource version"
}

variable "wlsoci_vmscripts_zip_bundle_path" {
  type        = string
  description = "Absolute path to the wlsoci vmscripts zip bundle that is generated by the build"
  default = "wlsoci-vmscripts.zip"
}
