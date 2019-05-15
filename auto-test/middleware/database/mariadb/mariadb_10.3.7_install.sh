#! /bin/bash

### Header info ###
## template: 	V01
## Author: 	WenYunbo w00442264
## name:	mariadb-10.3.7
## desc:	mariadb-10.3.7 compile and install

### RULE
## 1. update Header info
## 2. use pr_err/pr_tip/pr_ok/pr_info as print API
## 3. use ${ass_rst ret exp log} as result assert code
## 4. implement each Interface Functions if you need

### VARIS ###

# Color Macro Start 
MCOLOR_RED="\033[31m"
MCOLOR_GREEN="\033[32m"
MCOLOR_YELLOW="\033[33m"
MCOLOR_END="\033[0m"
# Color Macro End

##################################
## MariaDB pre-defination start ##
##################################
mariadb_version='10.3.7'
boost_version='1.66.0'
working_dir="/usr/local/src/mariadb-${mariadb_version}-base"
install_dir="/usr/local/mariadb-${mariadb_version}"

mariadb_srcfile_download='https://downloads.mariadb.org/interstitial/mariadb-10.3.7/source/mariadb-10.3.7.tar.gz/from/http%3A//ftp.hosteurope.de/mirror/archive.mariadb.org/'
mariadb_srcfile_name='mariadb-10.3.7.tar.gz'
mariadb_srcfile_sha256sum='e990afee6ae7cf9ac40154d0e150be359385dd6ef408ad80ea30df34e2c164cf'

boost_srcfile_download='https://dl.bintray.com/boostorg/release/1.66.0/source/boost_1_66_0.tar.gz'
boost_srcfile_name='boost_1_66_0.tar.gz'
boost_srcfile_sha256sum='bd0df411efd9a585e5a2212275f8762079fed8842264954675a4fddc46cfcf60'

mariadb_srcfile_unpacked="${mariadb_srcfile_name%.tar*}"
boost_srcfile_unpacked="${boost_srcfile_name%.tar*}"

##################################
## MariaDB pre-defination end ##
##################################

SRC_URL=NULL
PKG_URL=NULL
DISTRIBUTION=NULL
rst=0

## Selfdef Varis
# MY_SRC_DIR
# MY_SRC_TAR


### internal API ###

function pr_err()
{
	if [ "$1"x == ""x ] ; then
		echo -e $MCOLOR_RED "Error!" $MCOLOR_END
	else
		echo -e $MCOLOR_RED "$1" $MCOLOR_END
	fi
}

function pr_tip()
{
	if [ "$1"x != ""x ] ; then
		echo -e $MCOLOR_YELLOW "$1" $MCOLOR_END
	fi
}

function pr_ok()
{
	if [ "$1"x != ""x ] ; then
		echo -e $MCOLOR_GREEN "$1" $MCOLOR_END
	fi
}

function pr_info()
{
	if [ "$1"x != ""x ] ; then
		#echo " $1"
		echo -e " $1"
	fi
}

# assert result [  $1: check value; $2: expect value; $3 fail log  ]
function ass_rst() 
{
	if [ "$#"x != "3"x ] ; then
		pr_err "ass_rst param faill, only $#, expected 3"
		return 1
	fi

	if [ "$1"x != "$2"x ] ; then
		pr_err "$3"
		exit 1
	fi

	return 0
}

### Interface Functions ###
## Interface list:
##	check_distribution()
##	clear_history()
##	install_depend()
##	download_src()
##		download src
##		untar & cd topdir
##	compile_and_install()
##		toggle to the right version
##		remove git info
##		configure & compile
##		install
##	selftest()
##  finish_install()
##		remove files

## Interface: get distribution
function check_distribution()
{
	if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
		DISTRIBUTION='CentOS'
	elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
		DISTRIBUTION='Debian'
	else
		DISTRIBUTION='unknown'
	fi

	pr_tip "Distribution : ${DISTRIBUTION}"

	return 0
}

## Interface: clear history files to prepare for reinstall files
function clear_history()
{
	pr_tip "[clear] skiped"
	return 0
}

## Interface: install dependency
function install_depend()
{
	if [ "${DISTRIBUTION}" = "CentOS" ]; then
		prerequisites='gcc gcc-c++ wget lsof m4 bison cmake automake zlib zlib-devel libaio libaio-devel ncurses ncurses-devel gnutls gnutls-devel openssl openssl-devel libevent libevent-devel'
		for arg in ${prerequisites}
		do
			tester=$(rpm -qa|grep -c "^${arg}-")
			if [ ${tester} -eq 0 ]; then
				pr_info "[install_depend] Installing ${arg}\c"
				yum install -q -y ${arg}
				ass_rst $? 0 "[install_depend] Error: Failed to install ${arg}."
				pr_info "...OK!"
			else
				pr_info "[install_depend] Found ${arg}."
			fi
			unset tester
		done
		unset prerequisites
		unset arg
	elif [ "${DISTRIBUTION}" = "Debian" ]; then
		prerequisites='gcc g++ wget lsof m4 bison cmake automake zlib1g zlib1g-dev libaio1 libaio-dev ncurses-base libncurses5-dev libncursesw5-dev gnutls-bin libgnutls28-dev openssl libssl-dev libevent-dev'
		for arg in ${prerequisites}
		do
			tester=$(dpkg -l|grep -c "^ii  ${arg}")
			if [ ${tester} -eq 0 ]; then
				pr_info "[install_depend] Installing ${arg}\c"
				apt-get --assume-yes -qq install ${arg}
				ass_rst $? 0 "[install_depend] Error: Failed to install ${arg}."
				pr_info "...OK!"
			else
				pr_info "[install_depend] Found ${arg}."
			fi
			unset tester
		done
		unset prerequisites
		unset arg
	else
		pr_err "[install_depend] Error: DISTRIBUTION unknown."
		exit 1
	fi

	return 0
}

## Interface: download_src
function download_src()
{
	# Check command "wget" & "sha256sum"
	if [ ! -x "$(command -v wget)" ]; then
		pr_err "[download_src] Error: Command \"wget\" not found. Unable to download source-code."
		exit 1
	fi
	
	if [ ! -x "$(command -v sha256sum)" ]; then
		pr_err "[download_src] Error: Command \"sha256sum\" not found. Unable to verify source-code integrity."
		exit 1
	fi

	# Prepare working_dir & install_dir
	if [ -e "${working_dir}/my_build" ]; then
		pr_info "[download_src] Found old building-dir: \"${working_dir}/my_build\". Do you wish to remove it? [Y/N]: \c"
		while true; do
		    read yn
		    case $yn in
			[Yy]* ) rm -rf "${working_dir}/my_build"; break;;
			[Nn]* ) exit 1;;
			* ) pr_info "Please reply Y or N: \c";;
		    esac
		done	
		unset yn
		if [ -e "${working_dir}/my_build" ]; then
			pr_err "[download_src] Error: Failed to remove \"${working_dir}/my_build\"."
			exit 1
		fi
	fi
	
	if [ -e "${install_dir}" ]; then
		pr_info "[download_src] Found old install-dir: \"${install_dir}\". Do you wish to remove it? [Y/N]: \c"
		while true; do
		    read yn
		    case $yn in
			[Yy]* ) rm -rf "${install_dir}"; break;;
			[Nn]* ) exit 1;;
			* ) pr_info "Please reply Y or N: \c";;
		    esac
		done	
		unset yn
		if [ -e "${install_dir}" ]; then
			pr_err "[download_src] Error: Failed to remove \"${install_dir}\"."
			exit 1
		fi
	fi

	mkdir -p ${working_dir}/my_build/my_log
	ass_rst $? 0 "[download_src] Error: Failed to create building-dir."
	pr_info "[download_src] new building-dir created: \"${working_dir}/my_build\"."
	mkdir -p ${install_dir}/etc ${install_dir}/tmp ${install_dir}/var/log ${install_dir}/var/run/mysqld ${install_dir}/my_tools
	ass_rst $? 0 "[download_src] Error: Failed to create install-dir."
	pr_info "[download_src] new install-dir created: \"${install_dir}\"."

	if [ ! -e "${working_dir}/my_source" ]; then
		mkdir -p ${working_dir}/my_source
		ass_rst $? 0 "[download_src] Error: Failed to create \"${working_dir}/my_source\"."
	elif [ ! -d "${working_dir}/my_source" ]; then
		rm -rf ${working_dir}/my_source
		ass_rst $? 0 "[download_src] Error: Failed to remove \"${working_dir}/my_source\"."
		mkdir -p ${working_dir}/my_source
		ass_rst $? 0 "[download_src] Error: Failed to create \"${working_dir}/my_source\"."
	else
		:	
	fi	
	
	if [ -e "${working_dir}/my_source/check.sha256" ]; then
		rm -rf ${working_dir}/my_source/check.sha256
		ass_rst $? 0 "[download_src] Error: Failed to remove \"${working_dir}/my_source/check.sha256\"."
		echo -e "${mariadb_srcfile_sha256sum} ${mariadb_srcfile_name}\n${boost_srcfile_sha256sum} ${boost_srcfile_name}" > ${working_dir}/my_source/check.sha256
		ass_rst $? 0 "[download_src] Error: Failed to create \"${working_dir}/my_source/check.sha256\"."
	else
		echo -e "${mariadb_srcfile_sha256sum} ${mariadb_srcfile_name}\n${boost_srcfile_sha256sum} ${boost_srcfile_name}" > ${working_dir}/my_source/check.sha256
		ass_rst $? 0 "[download_src] Error: Failed to create \"${working_dir}/my_source/check.sha256\"."
	fi
	pr_info "[download_src] new check-file created: \"${working_dir}/my_source/check.sha256\"."


	# work inside working_dir
	cd ${working_dir}/my_source
	ass_rst $? 0 "[download_src] Error: Failed to execute \"cd ${working_dir}/my_source\"."
	check_boost=$(grep "${boost_srcfile_name}" check.sha256 | sha256sum -c 2>/dev/null | grep "OK" | wc -l)
	check_mariadb=$(grep "${mariadb_srcfile_name}" check.sha256 | sha256sum -c 2>/dev/null | grep "OK" | wc -l)

	# download mariadb and boost source-code
	pr_tip "[download_src] --> Preparing source-code. Please wait..."
	if [ ${check_boost} -eq 1 ]; then
		pr_info "[download_src] Found available boost source-code: \"${working_dir}/my_source/${boost_srcfile_name}\"."
	else
		unset check_boost
		if [ -e "${working_dir}/my_source/${boost_srcfile_name}" ]; then
			pr_tip "[download_src] Removing broken source-code: \"${working_dir}/my_source/${boost_srcfile_name}\"."
			rm -rf ${working_dir}/my_source/${boost_srcfile_name}
			ass_rst $? 0 "[download_src] Error: Failed to remove \"${working_dir}/my_source/${boost_srcfile_name}\"."
		fi
		
		pr_tip "\n\n[download_src] Downloading boost source-code. Please wait..."
		wget "${boost_srcfile_download}" --no-check-certificate -O ${working_dir}/my_source/${boost_srcfile_name}
		ass_rst $? 0 "[download_src] Error: Failed to download boost source-code."
		pr_info "[download_src] Download success: \"${working_dir}/my_source/${boost_srcfile_name}\"."
		
		pr_tip "[download_src] Verifying integrity..."
		check_boost=$(grep "${boost_srcfile_name}" check.sha256 | sha256sum -c | grep "OK" | wc -l)
		if [ ! ${check_boost} -eq 1 ]; then
			pr_err "[download_src] Error: Failed to verify integrity. \"${working_dir}/my_source/${boost_srcfile_name}\" might be broken."
			exit 1
		else
			pr_info "[download_src] Verifying integrity success."
		fi
	fi

	if [ ${check_mariadb} -eq 1 ]; then
		pr_info "[download_src] Found available mariadb source-code: \"${working_dir}/my_source/${mariadb_srcfile_name}\"."
	else
		unset check_mariadb
		if [ -e "${working_dir}/my_source/${mariadb_srcfile_name}" ]; then
			pr_tip "[download_src] Removing broken source-code: \"${working_dir}/my_source/${mariadb_srcfile_name}\"."
			rm -rf ${working_dir}/my_source/${mariadb_srcfile_name}
			ass_rst $? 0 "[download_src] Error: Failed to remove \"${working_dir}/my_source/${mariadb_srcfile_name}\"."
		fi
		
		pr_tip "\n\n[download_src] Downloading mariadb source-code. Please wait..."
		wget "${mariadb_srcfile_download}" --no-check-certificate -O ${working_dir}/my_source/${mariadb_srcfile_name}
		ass_rst $? 0 "[download_src] Error: Failed to download mariadb source-code."
		pr_info "[download_src] Download success: \"${working_dir}/my_source/${mariadb_srcfile_name}\"."
		
		pr_tip "[download_src] Verifying integrity..."
		check_mariadb=$(grep "${mariadb_srcfile_name}" check.sha256 | sha256sum -c | grep "OK" | wc -l)
		if [ ! ${check_mariadb} -eq 1 ]; then
			pr_err "[download_src] Error: Failed to verify integrity. \"${working_dir}/my_source/${mariadb_srcfile_name}\" might be broken."
			exit 1
		else
			pr_info "[download_src] Verifying integrity success."
		fi
	fi
	pr_ok "[download_src] <-- Preparing source-code success! "

	# unpacking source-code
	pr_tip "[download_src] --> Unpacking source-code. Please wait..."
	if [ -d "${working_dir}/my_source/${boost_srcfile_unpacked}" ]; then
		rm -rf ${working_dir}/my_source/${boost_srcfile_unpacked}
		ass_rst $? 0 "[download_src] Error: Failed to remove \"${working_dir}/my_source/${boost_srcfile_unpacked}\"."
	fi
	tar -xmf ${boost_srcfile_name}
	ass_rst $? 0 "[download_src] Error: Unpacking ${boost_srcfile_name} failed."
	if [ ! -d "${working_dir}/my_source/${boost_srcfile_unpacked}" ]; then
		pr_err "[download_src] Error: "${working_dir}/my_source/${boost_srcfile_unpacked}" not found."
		exit 1
	fi
	
	if [ -d "${working_dir}/my_source/${mariadb_srcfile_unpacked}" ]; then
		rm -rf ${working_dir}/my_source/${mariadb_srcfile_unpacked}
		ass_rst $? 0 "[download_src] Error: Failed to remove \"${working_dir}/my_source/${mariadb_srcfile_unpacked}\"."
	fi
	tar -xmf ${mariadb_srcfile_name}
	ass_rst $? 0 "[download_src] Error: Unpacking ${mariadb_srcfile_name} failed."
	if [ ! -d "${working_dir}/my_source/${mariadb_srcfile_unpacked}" ]; then
		pr_err "[download_src] Error: "${working_dir}/my_source/${mariadb_srcfile_unpacked}" not found."
		exit 1
	fi
	pr_ok "[download_src] <-- Unpacking source-code success! "

	return 0
}

## Interface: compile_and_install
function compile_and_install()
{
	pr_tip "[compile_and_install] --> Compiling MariaDB-${mariadb_version}. Please wait..."
	cd ${working_dir}/my_build
	ass_rst $? 0 "[compile_and_install] Error: Failed to execute \"cd ${working_dir}/my_build\"."

	if [ ! -r "${working_dir}/my_source/${mariadb_srcfile_unpacked}/storage/innobase/CMakeLists.txt" ]; then
		pr_err "[compile_and_install] Error: Failed to fix bug in CMakeLists.txt."
		exit 1
	else
		sed -i '/COMPILE_FLAGS "-O0"/i \      row/row0trunc.cc' ${working_dir}/my_source/${mariadb_srcfile_unpacked}/storage/innobase/CMakeLists.txt
		ass_rst $? 0 "[compile_and_install] Error: Failed to fix bug in CMakeLists.txt."
	fi

	cmake ${working_dir}/my_source/${mariadb_srcfile_unpacked} -DBUILD_CONFIG=mysql_release -DCMAKE_INSTALL_PREFIX=${install_dir} -DWITH_BOOST=${working_dir}/my_source/${boost_srcfile_unpacked} -DPLUGIN_AWS_KEY_MANAGEMENT=NO > ${working_dir}/my_build/my_log/my_cmake.log 2>&1 
	ass_rst $? 0 "[compile_and_install] Error: cmake Failed. See \"${working_dir}/my_build/my_log/my_cmake.log\"."
	[ "$(grep -c "CMake Error at" ${working_dir}/my_build/my_log/my_cmake.log)" -gt 0 ] \
	&& { pr_err "[compile_and_install] Error: cmake Failed. See \"${working_dir}/my_build/my_log/my_cmake.log\"."; exit 1; } 

	make -j $(nproc) > ${working_dir}/my_build/my_log/my_make.log 2>&1
	ass_rst $? 0 "[compile_and_install] Error: make Failed. See \"${working_dir}/my_build/my_log/my_make.log\"."
	[ "$(grep -c "] Error " ${working_dir}/my_build/my_log/my_make.log)" -gt 0 ] \
	&& { pr_err "[compile_and_install] Error: make Failed. See \"${working_dir}/my_build/my_log/my_make.log\"."; exit 1; } 
	pr_ok "[compile_and_install] <-- Compiling MariaDB-${mariadb_version} success!"

	pr_tip "[compile_and_install] --> Installing MariaDB-${mariadb_version}. Please wait..."
	make install > ${working_dir}/my_build/my_log/my_make_install.log 2>&1
	ass_rst $? 0 "[compile_and_install] Error: make install Failed. See \"${working_dir}/my_build/my_log/my_make_install.log\"."
	[ "$(grep -c "] Error " ${working_dir}/my_build/my_log/my_make_install.log)" -gt 0 ] \
	&& { pr_err "[compile_and_install] Error: make install Failed. See \"${working_dir}/my_build/my_log/my_make_install.log\"."; exit 1; } 
	pr_ok "[compile_and_install] <-- Installing MariaDB-${mariadb_version} success!"
	
	pr_info "\n[compile_and_install] MariaDB-${mariadb_version} is installed in ${install_dir}."
	
	return 0
}

## Interface: software self test
## example: print version number, run any simple example
function selftest()
{
	pr_tip "[selftest] Version check."
	v_test=$(${install_dir}/bin/mysql --version | grep -c "10.3.7-MariaDB")
	if [ ${v_test} -eq 0 ]; then
		pr_err "[selftest] Error: Version check failed."
		exit 1
	else
		pr_ok "[selftest] Version check success."
	fi
	
	return 0
}

## Interface: finish install
function finish_install()
{
	pr_tip "[finish]<clean> skiped"
	return 0
}

### Dependence ###

### Compile and Install ###

### selftest ###

### main code ###
function main()
{
	check_distribution
	ass_rst $? 0 "check_distribution failed!"

	clear_history
	ass_rst $? 0 "clear_history failed!"
	
	install_depend
	ass_rst $? 0 "install_depend failed!"
		
	download_src
	ass_rst $? 0 "download_src failed!"
	
	compile_and_install
	ass_rst $? 0 "compile_and_install failed!"
	
	selftest
	ass_rst $? 0 "selftest failed!"

	finish_install
	ass_rst $? 0 "finish_install failed"
}

pr_tip "-------- software compile and install start --------"
main
rst=$?

ass_rst $rst 0 "[FINAL] Software install,Fail!"

pr_ok " "
pr_ok "Software install OK!"

pr_tip "--------  software compile and install end  --------"
