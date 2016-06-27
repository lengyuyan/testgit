#!/bin/bash
#y00952 rewrite in 2015/09/06
#�����ں˽ű�������ά��ԭʼ�ں�Դ���������޸ĺ���Դ�������б��룬�ٸ��������ļ��ָ�ΪԭʼԴ����

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
trap "warn_exit" 2 20

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
			if [ -e $build_src_dir/$cell ];then #Ŀ¼�Ѿ�����
				backup_dir $cell/  #�ݹ鴦��Ŀ¼�ڲ��ļ���б�ܲ�����
			else #Ŀ¼�����ڣ�ֱ�ӿ�����ȥ������¼�����ٶ�����ľ����ļ����д���
				echo [New Dir] $cell
				/bin/cp -ap $new_src_dir/$cell $build_src_dir/$cell
				find $build_src_dir/$cell |xargs touch  #����ʱ�䣬ȷ���ܹ�����
				echo "$cell" >> $NEW_DIR_LIST; sync
			fi
		else #normal file
			if [ -e $build_src_dir/$cell ];then #�ļ����ڣ��ȱ���
				echo [Exi Sou] $cell
				/bin/cp -f $build_src_dir/$cell ${build_src_dir}/${cell}.bak
				/bin/cp -f $new_src_dir/$cell $build_src_dir/$cell
				touch $build_src_dir/$cell
				echo $cell >> $REPLACED_FILE_LIST;sync
			else # ���ļ���¼
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





#main entry 
cur_dir=`pwd`

#�������·���;���·��
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
#��¼�µ�¼��Ա�ͱ��뻷��
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

