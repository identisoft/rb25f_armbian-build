echo "Starting Eureka Setup...";
setenv eureka_tftp_server 192.1.3.1:/rb25f/RB25F_1.5.0.82_Debian_stretch_next_4.14.59.img.gz

if test "${restart}" = "1";
then
  echo "INFO - Retrying in 2 seconds...";
  sleep 2;
else
#  echo "INFO - Waiting for ethernet to settle...";
#  sleep 5;
  echo "INFO - Setting ENV variables"
# bootpretryperiod - This env variable sets the timeout delay to abort trying
# to obtain a valid ip address from the dhcp server. U-Boot defaults to a total
# timeout of about 34seconds, retrying every 2.
# For some reason, on first attempt to obtain a valid ip, this will fail and a
# 2nd attempt has to be made which is generally succesfull.
# This may just be due to a busy network and the tests being down with the same
# physical device, I.E. Dhcp server needed to release the ip prior to re-issue.
  setenv bootpretryperiod 2000;

# tftptime - Env variable used by U-Boot to re-quest missing packets in tftp
# download. U-boots default is 1000ms. Depending on network activity and how
# the tftp server is configured, this can cause more frequent missed packets
# resulting in a maxcount failure, and the tftp download being aborted.
  setenv tftptimeout 5000; #set on 5 seconds, shorter times may still work

# disable loading a default env
  setenv autoload no;
# variables used by this script to track what has been/still needs to be done
# if a failure occurs.
  #setenv eureka_dhcp_done 0;
  #setenv eureka_tftp_done 0;
  #setenv eureka_mmc_write_done 0;
fi
#setenv macdone 0;
if test "${restart}" != "${Done}";
then
	gpio clear 120
	sleep 1
	gpio set 120
fi

setenv restart 0;
setenv Not_Done 0;
setenv Done 1;

# Check for and load existing MAC address
if test "${macdone}" != "${Done}";
then
	echo "Product ID"
	editenv product_id;
	echo "MAC"
	env delete ethaddr;
	editenv ethaddr;
	echo "SerialNumber"
	env delete serial#;
	editenv serial#;
	setenv macdone 1;
else
	echo "Mac addr and serial already set"
	echo "MAC address currently set as ${ethaddr}"
	echo "Serial # is ${serial#}"	
fi

# Check for / Connect to DHCP server
if test "${eureka_dhcp_done}" != "${Done}";
then
  echo "INFO - Setting up DHCP";
  if dhcp;
  then
    echo "INFO - DHCP setup OK";
    setenv eureka_dhcp_done 1;
  else
    echo "ERROR - DHCP Failed.";
    setenv restart 1;
  fi
fi

# TFTP download image if not yet successfully downloaded.
if test "${eureka_dhcp_done}" = "${Done}";
then
  if test "${eureka_tftp_done}" != "${Done}";
  then
    echo "INFO - Starting TFTP download.";
    if tftp 0x40000000 ${eureka_tftp_server};
    then
      echo "INFO - TFTP Completed OK.";
      setenv eureka_tftp_done 1;
    else
      echo "ERROR - TFTP Failed.";
      setenv restart 1;
      exit
    fi
  fi
fi

# Write the image to the eMMC and reboot when done
if test "${eureka_dhcp_done}" = "${Done}";
then
  if test "${eureka_tftp_done}" = "${Done}";
  then
    if test "${eureka_mmc_write_done}" != "${Done}";
    then
      echo "INFO - Starting eMMC write.";
      if gzwrite mmc 1 0x40000000 ${filesize}
      then
        echo "INFO - eMMC write completed.";
				echo "setting up U-Boot Environment";
				env delete autoload; #not deleting ?
				env delete bootfile; #deleted
				env delete bootpretryperiod; #deleted
				env delete dnsip; #deleted
				env delete Done; #deleted
				env delete ethact; #deleted
				env delete eureka_dhcp_done; #deleted
				env delete eureka_mmc_write_done; #deleted
				env delete eureka_tftp_done; #deleted
				env delete eureka_tftp_server; #deleted
				env delete fel_booted;
				env delete gatewayip; #deleted
				env delete ipaddr; #deleted
				env delete netmask; #deleted
				env delete Not_Done; #deleted
				env delete restart; #deleted
				env delete serverip; #deleted
				env delete tftptimeout; #deleted
				env delete fileaddr; #deleted
				env delete filesize; #deleted

				setenv arch arm;
				setenv baudrate 115200;
				setenv board sunxi;
				setenv board_name sunxi;
				setenv boot_a_script 'load ${devtype} ${devnum}:${distro_bootpart} ${scriptaddr} ${prefix}${script}; source ${scriptaddr}';
				setenv boot_efi_binary 'if fdt addr ${fdt_addr_r}; then bootefi bootmgr ${fdt_addr_r};else bootefi bootmgr ${fdtcontroladdr};fi;load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} efi/boot/bootaa64.efi; if fdt addr ${fdt_addr_r}; then bootefi ${kernel_addr_r} ${fdt_addr_r};else bootefi ${kernel_addr_r} ${fdtcontroladdr};fi';
				setenv boot_extlinux 'sysboot ${devtype} ${devnum}:${distro_bootpart} any ${scriptaddr} ${prefix}extlinux/extlinux.conf';
				setenv boot_net_usb_start usb start;
				setenv boot_prefixes / /boot/;
				setenv boot_script_dhcp boot.scr.uimg;
				setenv boot_scripts boot.scr.uimg boot.scr;
				setenv boot_targets fel mmc_auto usb0 pxe dhcp;
				setenv bootcmd run distro_bootcmd;
				setenv bootcmd_dhcp 'run boot_net_usb_start; if dhcp ${scriptaddr} ${boot_script_dhcp}; then source ${scriptaddr}; fi;setenv efi_fdtfile ${fdtfile}; setenv efi_old_vci ${bootp_vci};setenv efi_old_arch ${bootp_arch};setenv bootp_vci PXEClient:Arch:00011:UNDI:003000;setenv bootp_arch 0xb;if dhcp ${kernel_addr_r}; then tftpboot ${fdt_addr_r} dtb/${efi_fdtfile};if fdt addr ${fdt_addr_r}; then bootefi ${kernel_addr_r} ${fdt_addr_r}; else bootefi ${kernel_addr_r} ${fdtcontroladdr};fi;fi;setenv bootp_vci ${efi_old_vci};setenv bootp_arch ${efi_old_arch};setenv efi_fdtfile;setenv efi_old_arch;setenv efi_old_vci;';
				setenv bootcmd_fel 'if test -n ${fel_booted} && test -n ${fel_scriptaddr}; then echo '(FEL boot)'; source ${fel_scriptaddr}; fi';
				setenv bootcmd_mmc0 'setenv devnum 0; run mmc_boot';
				setenv bootcmd_mmc1 'setenv devnum 1; run mmc_boot';
				setenv bootcmd_mmc_auto 'if test ${mmc_bootdev} -eq 1; then run bootcmd_mmc1; run bootcmd_mmc0; elif test ${mmc_bootdev} -eq 0; then run bootcmd_mmc0; run bootcmd_mmc1; fi';
				setenv bootcmd_pxe 'run boot_net_usb_start; dhcp; if pxe get; then pxe boot; fi';
				setenv bootcmd_usb0 'setenv devnum 0; run usb_boot';
				setenv bootdelay 1;
#CHECK\/
#				setenv bootfile pxelinux.0;
#
				setenv bootm_size 0xa000000;
#Check\/
#				setenv bootpretryperiod 2000;
#
				setenv console ttyS0,115200;
				setenv cpu armv8;
				setenv dfu_alt_info_ram 'kernel ram 0x40080000 0x1000000;fdt ram 0x4FA00000 0x100000;ramdisk ram 0x4FE00000 0x4000000';
				setenv distro_bootcmd 'for target in ${boot_targets}; do run bootcmd_${target}; done';
				setenv efi_dtb_prefixes / /dtb/ /dtb/current/;
				setenv fdt_addr_r 0x4FA00000;
				#setenv fdtcontroladdr b9f2ab78;
				setenv fdtcontroladdr bpf2cc18;
				setenv fdtfile allwinner/sun50i-a64-eureka.dtb;
				setenv kernel_addr_r 0x40080000;
				setenv load_efi_dtb 'load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} ${prefix}${efi_fdtfile}';
				setenv mmc_boot 'if mmc dev ${devnum}; then setenv devtype mmc; run scan_dev_for_boot_part; fi';
				setenv mmc_bootdev 1;
				setenv preboot usb start;
				setenv pxefile_addr_r 0x4FD00000;
				setenv ramdisk_addr_r 0x4FE00000;
				setenv scan_dev_for_boot 'echo Scanning ${devtype} ${devnum}:${distro_bootpart}...; for prefix in ${boot_prefixes}; do run scan_dev_for_extlinux; run scan_dev_for_scripts; done;run scan_dev_for_efi;';
				setenv scan_dev_for_boot_part 'part list ${devtype} ${devnum} -bootable devplist; env exists devplist || setenv devplist 1; for distro_bootpart in ${devplist}; do if fstype ${devtype} ${devnum}:${distro_bootpart} bootfstype; then run scan_dev_for_boot; fi; done';
				setenv scan_dev_for_efi 'setenv efi_fdtfile ${fdtfile}; for prefix in ${efi_dtb_prefixes}; do if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}${efi_fdtfile}; then run load_efi_dtb; fi;done;if test -e ${devtype} ${devnum}:${distro_bootpart} efi/boot/bootaa64.efi; then echo Found EFI removable media binary efi/boot/bootaa64.efi; run boot_efi_binary; echo EFI LOAD FAILED: continuing...; fi; setenv efi_fdtfile';
				setenv scan_dev_for_extlinux 'if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}extlinux/extlinux.conf; then echo Found ${prefix}extlinux/extlinux.conf; run boot_extlinux; echo SCRIPT FAILED: continuing...; fi';
				setenv scan_dev_for_scripts 'for script in ${boot_scripts}; do if test -e ${devtype} ${devnum}:${distro_bootpart} ${prefix}${script}; then echo Found U-Boot script ${prefix}${script}; run boot_a_script; echo SCRIPT FAILED: continuing...; fi; done';
				setenv scriptaddr 0x4FC00000;
				setenv soc sunxi;
				setenv stderr serial,vidconsole;
				setenv stdin serial,usbkbd;
				setenv stdout serial,vidconsole;
				setenv usb_boot 'usb start; if usb dev ${devnum}; then setenv devtype usb; run scan_dev_for_boot_part; fi';

				env delete autoload;
				#sleep 1
				saveenv;
        echo "Rebooting...";
        #sleep 1
        reset
        #exit
      else
        echo "ERROR - eMMC write failed.";
        setenv restart 1;
      fi
    fi
  fi
fi

# if we get here, then something went wrong, so we just start the script again
# and retry.
if test "${restart}" = "${Done}";
then
  echo "Restarting Script";
  source 0xb0000000;
fi


