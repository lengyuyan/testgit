#!/bin/sh
#y00952 2013-11-06
#keep a source tree of original kernel
#check out modify source in same struct directory 

#disable CTRL+C CTRL+Z 
warn_exit() {
	echo "build kernel process will not exit before recover environmen!!!"
}
trap "warn_exit" 2 20
usage() {
    echo usage:
	echo "    $0  build_src_dir(rpmbuild/.../...) new_src_dir(svn get) "
	echo "        to build new kernel, and build dirctory will recover automaticlly"
	echo "	  $0  build_src_dir"
	echo "        to recover bak of build directory"
}

confirm_dir() {
	echo -e "Are you sure \033[31mbuild directory :\033[32m\033[1m $build_src_dir\033[0m"
	echo -e "and the  \033[31mnew source directory :\033[32m\033[1m  $new_src_dir\033[0m"
	echo -n "Input yes to confirm:"
	read input
	if [ "$input" = "y" -o "$input" = "Y" -o "$input" = "yes" -o "$input" = "YES" ]; then
		echo begin build kernel
	else
		echo build cancel
		exit
	fi
}

copy_bak() {
	if [ ! -f $1 ]; then
 		echo tips: $1 not exsit!
		cp -f $2 $1
		touch $1
		new_files=$new_files" "$1
	else
	   	mv $1 $1.bak
	   	cp -f $2 $1
		touch $1
		echo ok: $2
	fi
}

del_new() {
	for file in $new_files
	do
		echo del $file
		rm -f $file
	done
	new_files=""
}

build() {

#	find $new_src_dir -type d -name ".svn"|xargs rm -rf

	cd $new_src_dir
	files=$(find ./ -name "*"|grep -v ".svn")
	for file in $files
	do
		file=`echo $file|sed 's/^.//'`
    	if [ -f $new_src_dir$file ];then
			copy_bak $build_src_dir$file $new_src_dir$file
		fi
	done

    cd $build_src_dir
	make -j32 bzImage 
    mv $build_src_dir/arch/x86/boot/bzImage $cur_dir
}

recover() {
	build_src_dir=$1
	cd $build_src_dir
	
	bak_files=$(find ./ -name "*.bak")
	for bak_file in $bak_files
	do
		mv $bak_file `echo ${bak_file//.bak/}`
		touch `echo ${bak_file//.bak/}`
		echo ok: `echo ${bak_file//.bak/}`
	done
	del_new
}

if [ -n "`lsof|grep /home/kernel/rpmbuild/BUILD/kernel-3.10.0-229.el7/`" ];then
	echo somebody else is compiling
	echo please op later
	exit
fi

cur_dir=`pwd`
new_files=""
if [  $# -eq 2 -a -d "$1" -a -d "$2" ];then
	build_src_dir=$1
	if [ "`echo ${build_src_dir:0:1}`" != "/" ]; then
		build_src_dir=$cur_dir/$build_src_dir
	fi
	new_src_dir=$2
	if [ "`echo ${new_src_dir:0:1}`" != "/" ]; then
		new_src_dir=$cur_dir/$new_src_dir
	fi
	confirm_dir
	
	build $build_src_dir $new_src_dir
	recover $build_src_dir
elif [ $# -eq 1 -a -d "$1" ]; then
	build_src_dir=$1
	if [ "`echo ${build_src_dir:0:1}`" != "/" ]; then
		build_src_dir=$cur_dir/$build_src_dir
	fi
	recover $build_src_dir
else
	usage
	exit
fi



