#!/bin/sh
export TEMPNAME=/tmp/choice
export SOURCEDIR=/media
export TARGETDIR=/mnt
askforreboot(){
    dialog --yesno "Ready to reboot?" 18 60
    if [ $? = 0 ]
    then
        dialog --msgbox "Please take out the live CD and press OK" 18 60
        if [ $? = 0 ]
        then
            reboot
        fi
    else
        dialog --msgbox "Not rebooting. Please reboot anytime you want. Remember to take out the Live CD before rebooting" 18 60
    fi


}
installgrub(){
    dialog --yesno "Do you want to install grub?" 18 60
    if [ $? = 0 ]
    then
        MASTER=`cat /tmp/master`
        dialog --yesno "please check, you want to install grub in $MASTER" 18 60
        if [ $? = 0 ]
        then
            grub-install --root-directory=$TARGETDIR /dev/$MASTER
            if [ $? != 0 ]
            then echo "Error occured. Aborting..."
                exit
            else
                echo "Grub successfully installed at /dev/$MASTER"
            fi
            echo "Ready to update grub"
            mount -o bind /dev/ $TARGETDIR/dev
            mount -o bind /proc/ $TARGETDIR/proc
            mount -o bind /sys/ $TARGETDIR/sys
            chroot $TARGETDIR update-grub
            echo "Updating GRUB"
        else
            dialog --clear --menu "Select a hard disk to partition"\
                18 60 6 \
                hda "Primary IDE master" \
                hdb "Primary IDE slave" \
                hdc "Secondary IDE master" \
                hdd "Secondary IDE slave" \
                sda "First SCSI" \
                sdb "Second SCSI" 2>$TEMPNAME
            SELECTION=`cat $TEMPNAME`
            MASTER=`cat $TEMPNAME`
            grub-install --root-directory=$TARGETDIR /dev/$MASTER
            if [ $? != 0 ]
            then echo "Error occured. Aborting..."
                exit
            else
                echo "Grub successfully installed at /dev/$MASTER"
            fi
            echo "Ready to update grub"
            mount -o bind /dev/ $TARGETDIR/dev
            mount -o bind /proc/ $TARGETDIR/proc
            mount -o bind /sys/ $TARGETDIR/sys
            chroot $TARGETDIR update-grub
            echo "Updating GRUB"
        fi
    else echo "error occured. Aborting"
        exit
    fi
    askforreboot



}
installlinux(){
    dialog --menu "Select CD-ROM to install from" 18 60 6 \
        hda "Primary IDE master" \
        hdb "Primary IDE slave" \
        hdc "Secondary IDE master" \
        hdd "Secondary IDE slave" \
        sr0 "First SCSI" \
        sr1 "Second SCSI" 2>$TEMPNAME
    SELECTION=`cat $TEMPNAME`
    CDROM=`cat $TEMPNAME`
    mount -v /dev/$SELECTION /$SOURCEDIR
    if [ $? != 0 ]
    then
        dialog --msgbox "Mount failed!" 18 60
        exit 1
    fi
    if [ -f /tmp/rootfs ]
    then
        ROOTFS=`cat /tmp/rootfs`
    else
        ROOTFS=/dev/
    fi
    dialog --inputbox "Select root partition" 18 60\
        $ROOTFS 2>$TEMPNAME
    ROOTFS=`cat $TEMPNAME`
    echo -n $ROOTFS >/tmp/rootfs
    mount -t ext4 $ROOTFS $TARGETDIR
    if [ $? != 0 ]
    then
        dialog --msgbox "Mount failed!" 18 60
        umount $SOURCEDIR
        exit 1
    fi
    cd $TARGETDIR
    unsquashfs $SOURCEDIR/boot/x86_64/root.sfs
    mv -v squashfs-root/* $TARGETDIR
    rm -rfv $TARGETDIR/squashfs-root/
    rm -fv $TARGETDIR/etc/fstab
    touch $TARGETDIR/etc/fstab
    echo "updating fstab"
    echo "# Begin /etc/fstab">>$TARGETDIR/etc/fstab
    echo "# <file system> <mount point> <type> <options> <dump> <pass>">>$TARGETDIR/etc/fstab
    dialog --yesno "Please check, $ROOTFS is the root partition" 18 60
    if [ $? = 0 ]
    then
        echo "#Root partition was at $ROOTFS during installation">>$TARGETDIR/etc/fstab
        echo "$ROOTFS / ext4 errors=remount-ro 1 1">>$TARGETDIR/etc/fstab
    fi
    if [ -f /tmp/swappart ]
    then
        SELECTION=`cat /tmp/swappart`
        dialog --yesno "please check $SELECTION is the swap partition" 18 60
        if [ $? = 0 ]
        then
            echo "Swap partition was at $SELECTION during installation">>$TARGETDIR/etc/fstab
            echo "$SELECTION swap swap pri=1 0 0">>$TARGETDIR/etc/fstab
        fi
    fi
    echo "proc /proc proc nosuid,noexec,nodev 0 0">>$TARGETDIR/etc/fstab
    echo "sysfs /sys sysfs nosuid,noexec,nodev 0 0">>$TARGETDIR/etc/fstab
    echo "devpts /dev/pts devpts gid=5,mode=620 0 0">>$TARGETDIR/etc/fstab
    echo "tmpfs /run tmpfs defaults 0 0">>$TARGETDIR/etc/fstab
    echo "devtmpfs /dev devtmpfs mode=0755,nosuid 0 0">>$TARGETDIR/etc/fstab
    echo "dev/$CDROM /media/cdrom udf,iso9660 user,noauto 0 0">>$TARGETDIR/etc/fstab
    echo "">>$TARGETDIR/etc/fstab
    echo "# End /etc/fstab">>$TARGETDIR/etc/fstab
    installgrub




}
makeswap(){
    dialog --yesno "Do you want a swap partition?" 18 60
    if [ $? = 0 ]
    then
        dialog --inputbox "Enter the name of your swap partition"\
            5 60 /dev/ 2>$TEMPNAME
        SELECTION=`cat $TEMPNAME`

        dialog --yesno \
            "Any data on $SELECTION will be erased forever!\n
        Are you really sure you want to continue?" 18 60

        if [ $? = 0 ]
        then
            echo -n $SELECTION >/tmp/swappart
            mkswap $SELECTION
            swapon $SELCTION
            installlinux
        fi
    else
        installlinux

    fi




}
makeroot(){
    dialog --inputbox "Enter the name of your root partition"\
        5 60 /dev/ 2>$TEMPNAME
    SELECTION=`cat $TEMPNAME`

    dialog --yesno \
        "Any data on $SELECTION will be erased forever!\n
    Are you really sure you want to continue?" 18 60

    if [ $? = 0 ]
    then
        echo -n $SELECTION >/tmp/rootfs
        mkfs.ext4 $SELECTION
        makeswap
    else
        echo "Aborting"
        exit
    fi
}
partition(){
    dialog --yesno "Do you want to partition your hard disk?" 18 60
    if [ $? = 0 ]
    then dialog --clear --menu "Select a hard disk to partition"\
            18 60 6 \
            hda "Primary IDE master" \
            hdb "Primary IDE slave" \
            hdc "Secondary IDE master" \
            hdd "Secondary IDE slave" \
            sda "First SCSI" \
            sdb "Second SCSI" 2>$TEMPNAME
        SELECTION=`cat $TEMPNAME`
        MASTER=`cat $TEMPNAME`
        echo "$MASTER">>/tmp/master
        cfdisk /dev/$SELECTION
    else makeroot
    fi



}
disclaimer() {
    dialog --yesno "Welcome to installing Papiya GNU/Linux. Please be aware that it is in alpha stage. It may brick your device. Do you want to continue?" 18 60
    if [ $? = 0 ]
    then partition
    else
        echo "Aborting"
        exit
    fi
}
disclaimer
