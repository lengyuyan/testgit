#!/bin/sh
#y00952 2013-11-06
#keep a source tree of original kernel
#check out modify source in same struct directory 

#disable CTRL+C CTRL+Z 
warn_exit() {
	echo "build kernel process will not exit before recover environmen!!!"
}
trap "warn_exit" 2 20   #��ִ�нű���ʱ��׽�źţ������ǲ�׽CTRL+C CTRL+Z ���źžͻ�ִ��˫�����еĺ���

###################################################################
#���ܣ���ʾ��ȷ���������Ŀ¼�Ƿ���ȷ
#�����ں˵Ĵ���
#1,./build_kernel_org.sh  build_src_dir(rpmbuild/.../...) new_src_dir(svn get)��ָ��Դ���linux_kernel�͸Ķ����ں˵�linux_kernel,���������ں˺�,����Ŀ¼�����Զ���ԭ��ԭ��������
#   ע�����ﴴ��ȥ��Դ��Ŀ¼�Ǻʹ˱���ű�ͬ����һ�����Ŀ¼����build_kernel_org.sh��rpmbuild����ͬһ��Ŀ¼�£���ʱ��rpmbuild/kernel-2.6.32-220.el6/linux-2.6.32-220.el6.x86_64,���뵱ǰĿ¼���һ��
#    Ҳ�����Ǿ���Ŀ¼·�����Ķ����ں�·��ͬ��һ�������Խ��鴫����·��
# 2,./build_kernel_org.sh  build_src_dir����ԭ�����ں�
###################################################################


usage() {
    echo usage:
	echo "    $0  build_src_dir(rpmbuild/.../...) new_src_dir(svn get) "
	echo "        to build new kernel, and build dirctory will recover automaticlly"
	echo "	  $0  build_src_dir"
	echo "        to recover bak of build directory"
}

###################################################################
#���ܣ���ʾ��ȷ���������Ŀ¼�Ƿ���ȷ
#-e��ʾ����ת���ַ����� -n��ʾȡ������
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
#���ܣ������Ķ����ļ���Դ��Ŀ¼��
#1�����Դ����û�иĶ���Ŀ¼�е��ļ�echo tips: $1 not exsit!�Ҵ���һ���������ļ���new_files=$new_files" "$1�е�$new_files�ǿ�ʼ����Ŀգ������´������ļ���ǰ����˿ո񣬱�ʾ���ǿ��ļ�
#2������У����Դ���е�ͬ���ļ����ݣ�Ȼ�󿽱����ļ���������echo ok ���ļ�
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
#���ܣ��ѱ��ݵ�Ŀ¼�ĳ�ԭ��������
#del_new��ɾ��ԭ����Դ����û�е��ļ�
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
#���ܣ������ںˣ�����Ϊ�ں�Դ��Ŀ¼�����ں�Ŀ¼
#1���߽��Ķ����ں˵�Ŀ¼��Ȼ����ҵ�����.svn����Щ�ļ���Ҳ���ǸĶ��˵���Щ�ļ������޳���Щ.�ļ�
#2������copy_bak $build_src_dir$file $new_src_dir$file���ݾ��ļ����������ļ�
#3,�߽�Դ��Ŀ¼,ִ��make -j32 bzImage������bzImage��Դ��Ŀ¼;Ȼ�󿽱�bzImage����ǰĿ¼
###################################################################
build() {

#	find $new_src_dir -type d -name ".svn"|xargs rm -rf  #findһЩ.svn�ļ�Ȼ��ͨ��xargsɾ����Щ������ļ�

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
#���ܣ��ѱ��ݵ�Ŀ¼�ĳ�ԭ��������
#
#del_new��ɾ�����ļ�
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
#���ܣ������ǽű�������ʼִ�еĵط�,���������trap "" 2 20
#1��lsof �г�ϵͳ�д򿪵��ļ�,Ҳ���ǲ�ѯ˭���ں�Ŀ¼�У�Ҳ�����ں�Ŀ¼������/home/kernel/**�У����Ŀ¼�Ǵ������ĵ�һ������Ŀ¼�ĸ�Ŀ¼��
#     Ҳ����˵���Լ�������һ��������Ŀ¼��Ȼ���ϵ�һ����������Ϳ����Լ��������ں��ˣ�������һ��Ҫ/home/kernel/rpmbuild/BUILD�е��ں�,��BUILDƽ�еļ���Ŀ¼�б�Ҫ��
#     ���н����ڱ������������ں��ļ�������������ʱ��ȥ��������Ҫ��ͬʱ���룩������ʾ�Ժ����
#2����õ�ǰĿ¼,���Դ�����Ŀ¼�����Ķ����ں�Ŀ¼�Ƿ���ڣ�����������������������ͱ�ʾ�����ںˣ�Ȼ��ָ�Դ��Ϊ����ǰ�������
#   �����Ѵ������ı���Դ��Ŀ¼�͵�ǰĿ¼���һ������·����Դ��Ŀ¼�����ﴫ������Ŀ¼��Ҫ�ر�ע���������Ŀ¼��
#    ����confirm_dirȷ��������������뺯��build�������ںˣ�����ȥ���������� ���ɵ�bzImage��������ǰĿ¼
#    ����recover $build_src_dir �ѱ��ݵ�Ŀ¼�ĳ�ԭ��������
#
#3������Ϊ1��Դ��·������ֻ�ǻ�ԭԴ�뻷��
#     
###################################################################
#����������ûʲô��,Ӧ�û��ɶ������Դ��Ŀ¼���м��
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



