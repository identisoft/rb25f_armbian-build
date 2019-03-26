
<h1>**HID RB25F Image Builder**</h1>

Supported environment is Ubuntu 16.04 or 18.04 running in a VM with +- 20GB free hdd space and +- 2GB ram.

clone the script
	git clone https://github.com/rb25f_armbian-build.git  
	run build.sh  

------------

The script will create a new parrallel directory called build and proceed to download relevent 
toolchains and source code.  

See the build/config-default.conf file for further configuration options if you're working on test builds.

Any files needed to be copied over to be added to the image at build time need to go into  
  build/userpatches/overlay
This directory is bind mounted to tmp/overlays in the image rootfs  
modify build/userpatches/customize-image.sh with any image customizations.

Any patches required need to be placed in build/userpatches under the module to  
be modified, I.E atf,u-boot,kernel.

NOTE ** To build an upgraded kernel version, Ubuntu 18.04 is required.