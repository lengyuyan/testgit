#!/bin/bash
#y00952 rewrite in 2015/09/06
#编译内核脚本，用于维持原始内核源码树，将修改合入源码树进行编译，再根据配置文件恢复为原始源码树

###################################################################
#功能：编译内核脚本改进版
#./build_kernel.sh  build build_dir(rpmbuild/.../...) new_src_dir(svn get) ：to build new kernel, and need recover manually
#./build_kernel.sh  recover build_src_dir ：to recover build directory
#./build_kernel.sh  build build_dir(rpmbuild/.../...) new_src_dir(svn get) ：to build new kernel, and build dirctory will recover automaticly

###################################################################
usage() {
    echo -e "\nuseage():"
	echo -e "\t$0  \033[1mbuild\033[0m build_dir(rpmbuild/.../...) new_src_dir(svn get) "
	echo -e "\t\tto build new kernel, and need recover manually\n"
	echo -e "\t$0  \033[1mrecover\033[0m build_src_dir"
	echo -e "\t\tto recover build directory\n"
	echo -e "\t$0  \033[1mbuild_recover\033[0m build_dir(rpmbuild/.../...) new_src_dir(svn get) "
	echo -e "\t\tto build new kernel, and build dirctory will recover automaticly\n"	
	exit 1
}





#disable CTRL+C CTRL+Z 
warn_exit() {
	echo "build kernel process will not exit before recover environmen!!!"
}

#在执行脚本的时候捕捉信号，这里是捕捉CTRL+C CTRL+Z 有信号就会执行双引号中的函数
trap "warn_exit" 2 20

###################################################################
#功能：提示你确认你输入的目录是否正确
###################################################################
confirm_dir() {
	echo -e "Are you sure "
	echo -e "  \033[31mbuild      directory :\033[32m\033[1m $build_src_dir\033[0m"
	echo -e "  \033[31mnew source directory :\033[32m\033[1m $new_src_dir\033[0m"
	echo -n "Input yes to confirm:"
	read input
	case $input in
		y|Y|[yY][eE][sS])
			echo
		;;
		*)
			echo Build cancel!!
			exit 1
		;;
	esac

}

###################################################################
#功能：提示你确认你输入的目录是否正确
###################################################################
backup_all(){
	[ -e $NEW_DIR_LIST -o -e $NEW_FILE_LIST -o -e $REPLACED_FILE_LIST ] && echo Some one is compiling!!&&usage

	touch $NEW_DIR_LIST $NEW_FILE_LIST $REPLACED_FILE_LIST
	sync

	echo -e "\n--------------Begin backup-------------"
	cd $new_src_dir
	backup_dir
	cd - >/dev/null
	echo -e "--------------Finish backup------------\n"
}

#cd new dir to run function backup_dir
backup_dir(){
	elements=$(ls $1)
	for cell in $elements
	do
		cell=$1$cell
		if [ -n "`file $cell|awk -F : '{print $2}'|grep directory`" ];then #directory
			if [ -e $build_src_dir/$cell ];then #目录已经存在
				backup_dir $cell/  #递归处理目录内部文件，斜杠不能少
			else #目录不存在，直接拷贝过去，并记录，不再对里面的具体文件进行处理
				echo [New Dir] $cell
				/bin/cp -ap $new_src_dir/$cell $build_src_dir/$cell
				find $build_src_dir/$cell |xargs touch  #更新时间，确保能够编译
				echo "$cell" >> $NEW_DIR_LIST; sync
			fi
		else #normal file
			if [ -e $build_src_dir/$cell ];then #文件存在，先备份
				echo [Exi Sou] $cell
				/bin/cp -f $build_src_dir/$cell ${build_src_dir}/${cell}.bak
				/bin/cp -f $new_src_dir/$cell $build_src_dir/$cell
				touch $build_src_dir/$cell
				echo $cell >> $REPLACED_FILE_LIST;sync
			else # 新文件记录
				echo [New Sou] $cell
				/bin/cp -f $new_src_dir/$cell $build_src_dir/$cell
				touch $build_src_dir/$cell
				echo $cell >> $NEW_FILE_LIST ;sync
			fi
		fi
	done
}

recover_all(){
	echo -e "\n--------------Begin recover------------"
	cd $build_src_dir

	cat $NEW_DIR_LIST|while read line
	do
		echo -e "delete\t[New Dir] $line"
		rm -rf $build_src_dir/$line
	done

	cat $NEW_FILE_LIST|while read line
	do
		echo -e "delete\t[New Sou] $line"
		rm -rf $build_src_dir/$line
	done

	cat $REPLACED_FILE_LIST |while read line
	do
		echo -e "recover\t[Exi Src] $line"
		/bin/mv -f ${build_src_dir}/${line}.bak ${build_src_dir}/${line}
		touch ${build_src_dir}/${line}
	done
	rm -rf $NEW_DIR_LIST $NEW_FILE_LIST $REPLACED_FILE_LIST
	sync

	cd - >/dev/null
	echo -e "--------------Finish recover------------\n"
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

#main entry 
cur_dir=`pwd`

#兼容相对路径和绝对路径
[ "$1" != "build" -a "$1" != "recover" -a "$1" != "build_recover" ] && usage
build_src_dir=$2
if [ "`echo ${build_src_dir:0:1}`" != "/" ]; then
	build_src_dir=$cur_dir/$build_src_dir
fi
new_src_dir=$3
if [ "`echo ${new_src_dir:0:1}`" != "/" ]; then
	new_src_dir=$cur_dir/$new_src_dir
fi

if [ -n "`lsof|grep -w $build_src_dir`" ];then
	lsof|grep "$build_src_dir"
	echo Someones are editting files in $build_src_dir, Build cancel!
	exit 1
fi

confirm_dir
#记录下登录人员和编译环境
date >> $build_src_dir/last_users_info
who >> $build_src_dir/last_users_info
ps aux|grep $0|grep -v grep >> $build_src_dir/last_users_info

NEW_DIR_LIST=$build_src_dir/.new_dir_list
NEW_FILE_LIST=$build_src_dir/.new_file_list
REPLACED_FILE_LIST=$build_src_dir/.replaced_file_list

case $1 in
	build)
		test -z "$2" -o -z "$3" && echo Invalid directory && usage
		backup_all
		cd $build_src_dir
		make -j32 bzImage > $cur_dir/build_log
		mv $build_src_dir/arch/x86/boot/bzImage $cur_dir
		cd -
	;;
	recover)
		test -z "$2" && echo Invalid directory && usage
		recover_all
	;;
	build_recover)
		test -z "$2" -o -z "$3" && echo Invalid directory && usage
		backup_all
		cd $build_src_dir
		make -j32 bzImage > $cur_dir/build_log
		mv $build_src_dir/arch/x86/boot/bzImage $cur_dir
		cd -
		recover_all
	;;
esac

