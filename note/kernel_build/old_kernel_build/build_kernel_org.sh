#!/bin/sh
#y00952 2013-11-06
#keep a source tree of original kernel
#check out modify source in same struct directory 

#disable CTRL+C CTRL+Z 
warn_exit() {
	echo "build kernel process will not exit before recover environmen!!!"
}
trap "warn_exit" 2 20   #在执行脚本的时候捕捉信号，这里是捕捉CTRL+C CTRL+Z 有信号就会执行双引号中的函数

###################################################################
#功能：提示你确认你输入的目录是否正确
#编译内核的处理：
#1,./build_kernel_org.sh  build_src_dir(rpmbuild/.../...) new_src_dir(svn get)：指定源码的linux_kernel和改动了内核的linux_kernel,编译完新内核后,编译目录将会自动复原从原来的样子
#   注意这里创建去的源码目录是和此编译脚本同及的一个相对目录，如build_kernel_org.sh与rpmbuild处于同一个目录下，传时传rpmbuild/kernel-2.6.32-220.el6/linux-2.6.32-220.el6.x86_64,它与当前目录组成一个
#    也可以是绝对目录路径，改动的内核路径同他一样，所以建议传绝对路径
# 2,./build_kernel_org.sh  build_src_dir：复原编译内核
###################################################################


usage() {
    echo usage:
	echo "    $0  build_src_dir(rpmbuild/.../...) new_src_dir(svn get) "
	echo "        to build new kernel, and build dirctory will recover automaticlly"
	echo "	  $0  build_src_dir"
	echo "        to recover bak of build directory"
}

###################################################################
#功能：提示你确认你输入的目录是否正确
#-e表示开启转义字符含义 -n表示取消换行
#
###################################################################
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

###################################################################
#功能：拷贝改动的文件到源码目录中
#1，如果源码中没有改动的目录中的文件echo tips: $1 not exsit!且创建一个这样的文件，new_files=$new_files" "$1中的$new_files是开始定义的空，这样新创建的文件名前面多了空格，表示这是空文件
#2，如过有，则把源码中的同名文件备份，然后拷贝新文件进来，并echo ok 新文件
###################################################################
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
###################################################################
#功能：把备份的目录改成原来的名字
#del_new：删除原来在源码中没有的文件
###################################################################
del_new() {
	for file in $new_files
	do
		echo del $file
		rm -f $file
	done
	new_files=""
}
###################################################################
#功能：编译内核，参数为内核源码目录和新内核目录
#1，走进改动了内核的目录，然后把找到除了.svn的那些文件，也就是改动了的那些文件，还剔除那些.文件
#2，调用copy_bak $build_src_dir$file $new_src_dir$file备份就文件，拷贝新文件
#3,走进源码目录,执行make -j32 bzImage，生成bzImage在源码目录;然后拷贝bzImage到当前目录
###################################################################
build() {

#	find $new_src_dir -type d -name ".svn"|xargs rm -rf  #find一些.svn文件然后通过xargs删除这些多余的文件

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

###################################################################
#功能：把备份的目录改成原来的名字
#
#del_new：删除新文件
###################################################################
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

###################################################################
#功能：下面是脚本真正开始执行的地方,除了上面的trap "" 2 20
#1，lsof 列出系统中打开的文件,也就是查询谁在内核目录中，也就是内核目录还是在/home/kernel/**中，这个目录是传进来的第一个参数目录的父目录，
#     也就是说我自己可以做一个这样的目录，然后结合第一个输入参数就可以自己来编译内核了，而不用一定要/home/kernel/rpmbuild/BUILD中的内核,与BUILD平行的几个目录有必要吗？
#     若有进程在编译的正在这个内核文件（不包括编译时进去，这里主要怕同时编译），就提示稍后编译
#2，获得当前目录,检查源码编译目录，及改动的内核目录是否存在，如果传进来是两个参数，就表示编译内核，然后恢复源码为编译前的情况：
#   这里会把传进来的编译源码目录和当前目录组成一个绝对路径的源码目录，这里传进来的目录是要特别注意了是相对目录；
#    调用confirm_dir确认输入参数，编译函数build来编译内核，传进去两个参数； 生成的bzImage拷贝到当前目录
#    调用recover $build_src_dir 把备份的目录改成原来的名字
#
#3，传参为1个源码路径，则只是还原源码环境
#     
###################################################################
#下面这个如果没什么用,应该换成对输入的源码目录进行检查
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



