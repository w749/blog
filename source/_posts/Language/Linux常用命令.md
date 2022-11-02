---
title: Linux常用命令
author: 汪寻
date: 2019-08-07
tags:
 - Linux
categories:
 - Language

---

Linux常用操作命令。

<!-- more -->


## 文件操作

### 文件夹/文件操作

```bash
# 新建文件夹
mkdir 文件名

# 删除文件夹/文件：
rm -rf 文件名/文件

# 移动文件夹/文件：
mv 原路径 新路径（也可用于修改文件名）

# 复制文件夹/文件：
cp 原路径 新路径

# 显示文件内容（英文全拼：concatenate）命令用于连接文件并打印到标准输出设备上：
cat 文件名

# 分页查看文件，操作命令和vim基本相同
less 文件名

# 查看文件状态
stat 文件夹

# 设置文件所有者：（将当前前目录下的所有文件与子目录的拥有者皆设为 runoob，群体的使用者 runoobgroup）；
chown -R runoob:runoobgroup

# 查看文件权限：
ls -ld 文件名称

# 修改用户对文件的权限：（用数字来表示权限）三个数字分别表示User、Group、及Other的权限。r=4，w=2，x=1
# 若要 rwx 属性则 4+2+1=7
# 若要 rw- 属性则 4+2=6
# 若要 r-x 属性则 4+1=5
chmod 777 file

# 远程复制：scp 是 linux 系统下基于 ssh 登陆进行安全的远程文件拷贝命令。（同一局域网或者与远程服务器）
# 若是复制到目标主机的同目录下，则目标主机后的地址写$PWD
scp local_file remote_username@remote_ip:remote_folder；

# 添加环境变量：
vim /etc/profile
# 在结尾添加export PATH="$PATH:/home/software/cmake-3.19.0-Linux-x86_64/bin"
# esc + :wq保存退出
# 使配置生效
source /etc/profile
```

### find文件查找
- -maxdepth level 最大搜索目录深度
- -mindepth level 最小搜索目录深度
- -depth 先处理目录下的文件再处理目录本身
- -name 文件名称 根据文件名查找，支持通配符，使用时要用引号括起来
- -iname 文件名称 不区分大小写
- -regex PATTERN 以PATTERN匹配整个文件路径，而非文件名称
- -user USERNAME 查找属主为指定用户的文件
- -group GROUPNAME 查找属组为指定组的文件
- -uid UserID 查找属主为指定UID的文件
- -gid GroupID 查找属组为指定GID的文件
- -nouser 查找没有属主的文件
- -nogroup 查找没有属组的文件
- -type TYPE 根据文件类型查找（f普通文件、d目录文件、l符号链接文件、s套接字文件、b块设备文件、c字符设备文件、p管道文件）
- -empty 空文件或目录
- -a 与，默认多个条件就是与关系
- -o 或
- -not 非，或者使用!
- -prune 排除目录
- -size [+|-]UNIT 根据文件大小查找，常用大小k、M、G、c；6k表示(5k,6k]，-6k表示[0,5k]，+6k表示(6k,∞)
- -mtime [+|-] DAY 根据修改或创建时间查找文件，单位为天
- -mmin [+|-] MINUTE 根据分钟查找文件
- -perm MODE 根据权限查找

```bash
find /etc -maxdepth 2 mindepth 2
find -regex ".*\.txt$"  # 查找.txt结尾
find -maxdepth 1 -name "*.md"  # 查找当前目录下.md结尾
find /home -type d -ls  # 查看/home下的所有目录
find /home -type d -empty  # 查找空文件或目录
find /etc -type d -o -type l | wc -l  # 或者
find /etc -path '/etc/security' -a -prune -o -name "*.conf"  # 排除目录
find / \( -path "/sys" -o -path "/proc" \) -a -prune -o -type f -a -mmin -1  # 排除/proc和/sys目录
find /var/log/ -mtime +3 -type f -print  # 查找三天前被改动的文件
find /var/log/ -mtime -3 -type f -print  # 查找三天内被改动的文件
find /var/log/ -mtime 3 -type f -print  # 查找第三天被改动的文件
find -name "*.md" -newermt '2022-09-02' ! -newermt '2022-09-06'  # 查找一段时间内的文件
find -mmin -1  # 查找一分钟内被改动的文件
find -maxdepth 1 -perm 644  # 查找当前目录下权限为644的文件
```

### 参数替换xargs
由于很多命令不支持管道|来传递参数，xargs用于产生某个命令的参数，xargs 可以读入 stdin 的数据，并且以空格符或回车符将 stdin 的数据分隔成为参数

```bash
seq 10 | xargs
ls "*.log" | xargs rm -rf  # 删除当前目录下的指定文件，谨慎使用
find /bin/ -perm /7000 | xargs ls -Sl  # 查找有特殊权限的文件并排序
```

### 硬链接软连接

```bash
# ln创建链接
ln test1 test2  # 默认建立硬链接，两个文件同步，删除一个另外一个照样存在
ln -s test1 test3  # 加s参数创建软链接，两个文件同步，删除test1后test3也不可访问

# 对于不允许创建硬链接的文件也可使用cp -l命令也可达到创建硬链接的效果
cp -rl /var/lib/docker/volumes/wordpress_db/_data/* ./db
```

### 重定向

```bash
# 将命令执行后在控制台打印的结果和错误重定向到黑洞，全扔掉
ls 1> /dev/null  # 1表示控制台打印的结果，2表示错误信息
ls > /dev/null 2>&1  # 简写，将所有结果都重定向到黑洞
ls > /dev/null 2>&1 &  # 让程序后台执行，不会阻塞控制台
ls >> tmp.log 2>&1 &  # 将结果打印到日志文件
ls >> stdout.log 2> stderr.log  # 分别重定向

# 多行重定向，将多行结果写入文件
cat > test << EOF
        This is line 1 of the message.
        This is line 2 of the message.
        This is line 3 of the message.
        This is line 4 of the message.
        This is the last line of the message.
       
EOF

# 重定向中的-
wget -O - http://www.wangxiaochun.com/testdir/hello.sh  # 不加-符号会把这个文件下载到当前文件夹，但是加上-会作为stdout输出
tar -cvf - /home | tar -xvf -  # 将/home下的文件打包，但不是打包到文件而是打包到stdout通过管道符传给后面的命令，后面的-则用来接收管道符前的stdout
```

### 转换或删除字符tr
```bash
tr 'a-z' 'A-Z' < /etc/issue  # 该命令会把/etc/issue中的小写字符都转换成大写字符
tr –d abc < /etc/fstab  # 删除fstab文件中的所有abc中任意字符
tr -s '-' ',' < test  # 将连续的-字符替换为一个单独的,字符，类似于去重后替换
tr -d '-' < test  # 删除所有的-字符
tr -d '\r' < windows.txt > windows2.txt  # 将 Windows 的文本转化 Linux的文本格式
```

### 下载wget
```bash
wget http://cn.wordpress.org/wordpress-3.1-zh_CN.zip  # 下载文件保存到当前目录
wget -O wordpress.zip http://www.centos.bz/download.php?id=1080  # 下载资源并保存到wordpress.zip
wget -c http://cn.wordpress.org/wordpress-3.1-zh_CN.zip  # 断点续传
wget -b http://cn.wordpress.org/wordpress-3.1-zh_CN.zip  # 后台下载
wget –tries=40 http://cn.wordpress.org/wordpress-3.1-zh_CN.zip  # 失败最大重试
wget -i list.txt  # 下载多个文件，list.txt保存多个链接
wget –ftp-user=USERNAME –ftp-password=PASSWORD url  # 使用wget用户名和密码认证的ftp下载
```

### 压缩和解压缩
#### gzip gunzip
gzip [OPTION]... FILE ...
- -k keep，保留原文件，Centos8
- -d 解压缩，相当于gunzip
- -c 结果输出至标准输出，保留原文件
- -# 指定压缩比，取值为1-9

```bash
gunzip file.gz  # 解压文件
zcat file.gz  # 不显式解压提前查看文件内容
gzip -c messages > messages.gz
gzip -c -d messages.gz > messages
zcat messages.gz > messages
cat messages | gzip > m.gz
```

#### bzip2 bunzip2
bzip2 [OPTION]... FILE ...
- -k keep，保留原文件
- -d 解压缩
- -c 结果输出至标准输出，保留原文件
- -# 指定压缩比，取值为1-9

```bash
bunzip2 file.bz2  # 解压缩
bzcat file.bz2  # 不显式解压提前查看文件内容
```

#### zip unzip
zip 可以实现打包目录和多个文件成一个文件并压缩，但可能会丢失文件属性信息，如：所有者和组信息，一般建议使用 tar 代替
```bash
zip  -r sysconfig.zip /etc/sysconfig/  # 打包并压缩
unzip sysconfig.zip  # 解压
unzip sysconfig.zip -d /tmp/config  # 解压缩至指定目录,如果指定目录不存在，会在其父目录（必须事先存在）下自动生成
```

#### tar
涉及参数太多，仅列举常用的操作
- -z 相当于gzip压缩工具
- -j 相当于bzip2压缩工具
- -J 相当于xz压缩工具
- --exclude 排除文件
```bash
tar -cpvf /PATH/FILE.tar FILE...  #  创建归档，保留权限
tar -rf /PATH/FILE.tar FILE...  # 追加文件至归档： 注：不支持对压缩文件追加
tar -t -f /PATH/FILE.tar  # 查看归档文件中的文件列表
tar zcvf /root/a.tgz  --exclude=/app/host1 --exclude=/app/host2 /app
tar zxvf test.tar.gz  # 解压
tar zxvf test.tar.gz -C /tmp  # 解压到指定目录
tar zcvf test.tar.gz test/ # 压缩
tar -xvf mysql-8.0.22-1.el8.x86_64.rpm-bundle.tar  # 解压tar文件
```

### 切割文件split
将一个文件分割为数个
- -行数 指定多少行切分为一个小文件
- -b字节 指定多少字节切分为一个小文件
- -C字节 与-b相似，但是在切分时尽量维持每行的完整性
- [输出文件名] 设置切割后的文件名前缀
```bash
split -6 test  # 按行数切割
split -C1024 test prefix-  # 指定前缀
```

## 用户和用户组

### 主要配置文件

- /etc/passwd：用户及其属性信息(名称、UID、主组ID等）
- /etc/shadow：用户密码及其相关属性
- /etc/group：组及其属性信息
- /etc/gshadow：组密码及其相关属性

### 管理用户命令

#### useradd新增用户
- -u UID 
- -o 配合-u 选项，不检查UID的唯一性
- -g GID 指明用户所属基本组，可为组名，也可以GID
- -c "COMMENT“ 用户的注释信息
- -d HOME_DIR 以指定的路径(不存在)为家目录
- -s SHELL 指明用户的默认shell程序，可用列表在/etc/shells文件中
- -G GROUP1[,GROUP2,...] 为用户指明附加组，组须事先存在
- -N 不创建私用组做主组，使用users组做主组
- -r 创建系统用户 CentOS 6之前: ID<500，CentOS7 以后: ID<1000
- -m 创建家目录，用于系统用户
- -M 不创建家目录，用于非系统用户
- -p 指定加密的密码

```bash
useradd -r -u 48 -g apache -s /sbin/nologin -d /var/www -c "Apache" apache
```

#### usermod修改用户属性
- -u UID: 新UID
- -g GID: 新主组
- -G GROUP1[,GROUP2,...[,GROUPN]]]：新附加组，原来的附加组将会被覆盖；若保留原有，则要同时使用-a选项
- -s SHELL：新的默认SHELL
- -c 'COMMENT'：新的注释信息
- -d HOME: 新家目录不会自动创建；若要创建新家目录并移动原家数据，同时使用-m选项
- -l login_name: 新的名字
- -L: lock指定用户,在/etc/shadow 密码栏的增加 ! 
- -U: unlock指定用户,将 /etc/shadow 密码栏的 ! 拿掉
- -e YYYY-MM-DD: 指明用户账号过期日期
- -f INACTIVE: 设定非活动期限，即宽限期

```bash
usermod -d /home/hnlinux root  # 修改用户登录目录
```

#### passwd修改用户密码
- -d：删除指定用户密码
- -l：锁定指定用户
- -u：解锁指定用户
- -e：强制用户下次登录修改密码
- -f：强制操作
- -n mindays：指定最短使用期限
- -x maxdays：最大使用期限
- -w warndays：提前多少天开始警告
- -i inactivedays：非活动期限
- --stdin：从标准输入接收用户密码,Ubuntu无此选项
```bash
passwd  # 修改当前用户密码
echo 123456 | passwd test --stdin  # 给指定用户设置密码，注意debian没有stdin参数
```

#### 其他命令
```bash
# userdel删除linux用户
userdel -rf test  # r表示强制删除，f表示删除家目录和邮箱

# id可以查看用户的ID信息
id root

# su切换用户
su - hdfs  # 切换到hdfs用户
su - hdfs -c "ls ~"  # 使用指定的用户执行命令，但不切换用户
```

### 管理用户组命令

```bash
# groupadd创建组
groupadd test

# groupmod修改组名称
groupmod -n newtest test

# groupdel删除组
groupdel -f test  # 强制删除，即使是用户的主组也强制删除组,但会导致无主组的用户不可用无法登录

# gpasswd，可以修改组密码也可以修改组的成员关系
# -a user 将user添加至指定组中
# -d user 从指定附加组中移除用户user
# -A user1,user2,... 设置有管理权限的用户列表
gpasswd -a wang admins  # 将wang用户加入admins组

# groupmems 可以管理附加组的成员关系
# -g, --group groupname   #更改为指定组 (只有root)
# -a, --add username     #指定用户加入组
# -d, --delete username #从组中删除用户
# -p, --purge               #从组中清除所有成员
# -l,  --list                 #显示组成员列表

# groups查看用户组关系
groups root
```

### 文件权限

每个文件针对三类访问者有三种不同的权限：

三类访问者分别是：文件所有用户，用户所有组和其他用户；三种权限分别是读、写和执行，对应的三个字母是r、w、x，对应的数字分别是4、2、1。给文件分配权限可以按照不同权限的组合相加分配给不同的访问者，比如777就是三类访问者都可以读写和执行。

```bash
# 设置文件的所有者chown
# chown [OPTION]... [OWNER][:[GROUP]] FILE...
# chown [OPTION]... --reference=RFILE FILE...
# OWNER   #只修改所有者
# OWNER:GROUP #同时修改所有者和属组
# :GROUP   #只修改属组，冒号也可用 . 替换
# --reference=RFILE  #参考指定的的属性，来修改   
# -R #递归修改
chown -R test:test /root/tmp

# 设置文件的属组信息chgrp
chgrp test /root/tmp  # chgrp只可以修改文件的所属组

# 修改文件权限chmod
chmod -R 755 /root/tmp

# 设定文件特殊权限
chattr +i file  # 不能删除、改名、更改
chattr +a file  # 只能追加，不能删除、改名
lsattr  # 显示特殊属性
```

### ACL设置
setfacl设定ACL权限
- -m：设定 ACL 权限。如果是给予用户 ACL 权限，则使用"u:用户名：权限"格式赋予；如果是给予组 ACL 权限，则使用"g:组名：权限" 格式赋予；
- -x：删除指定的 ACL 权限；
- -b：删除所有的 ACL 权限；
- -d：设定默认 ACL 权限。只对目录生效，指目录中新建立的文件拥有此默认权限；
- -k：删除默认 ACL 权限；
- -R：递归设定 ACL 权限。指设定的 ACL 权限会对目录下的所有子文件生效；
```bash
setfacl -m u:test:rx /root/tmp  # 给test用户设置tmp目录的ACL权限
setfacl -m g:tgroup2:rwx /root/tmp  # 给用户组分配ACL权限
setfacl -m d:u:test:rw /root/tmp/  # 给目录设置默认权限，这样目录内的新建文件也拥有ACL权限
setfacl -x u:test /root/tmp  # 删除指定用户的ACL权限
setfacl -b /root/tmp  # 删除所有的ACL权限

# getfacl获取文件的ACL权限
getfacl /root/tmp
```

## 文件处理

### VIM

#### 行号
```bash
显示：set number，简写 set nu
取消显示：set nonumber, 简写 set nonu
```

#### 忽略字符的大小写
```bash
启用：set ignorecase，简写 set ic
不忽略：set noic
```

#### 自动缩进
```bash
启用：set autoindent，简写 set ai
禁用：set noai
```

#### 复制保留格式
```bash
启用：set paste
禁用：set nopaste
```

#### 显示Tab ^I和换行符和$显示
```bash
启用：set list
禁用：set nolist
```
#### 高亮搜索
```bash
启用：set hlsearch
禁用：set nohlsearch 简写：nohl
```

#### 语法高亮
```bash
启用：syntax on
禁用：syntax off
```

#### 文件格式
```bash
启用windows格式：set fileformat=dos
启用unix格式：set fileformat=unix
简写 set ff=dos|unix
```

#### Tab用空格代替
```bash
启用：set expandtab   默认为8个空格代替Tab
禁用：set noexpandtab
简写：set et
```
#### Tab用指定空格的个数代替
```bash
启用：set tabstop=# 指定#个空格代替Tab
简写：set ts=4
```

#### 设置缩进宽度
```bash
#向右缩进 命令模式>>
#向左缩进 命令模式<<
#设置缩进为4个字符
set shiftwidth=4
```

##### 设置文本宽度
```bash
set textwidth=65 (vim only) #从左向右计数
set wrapmargin=15           #从右到左计数
```

#### 设置光标所在行的标识线
```bash
启用：set cursorline，简写 set cul
禁用：set nocursorline
```

#### 加密
```bash
启用： set key=password
禁用： set key=
```

#### 单词间跳转
```bash
w：下一个单词的词首
e：当前或下一单词的词尾
b：当前或前一个单词的词首
'#'COMMAND：由#指定一次跳转的单词数
```

#### 当前页跳转
```bash
H：页首     
M：页中间行     
L：页底
zt：将光标所在当前行移到屏幕顶端
zz：将光标所在当前行移到屏幕中间
zb：将光标所在当前行移到屏幕底端
```

#### 行首行尾跳转
```bash
^ 跳转至行首的第一个非空白字符
0 跳转至行首
\$ 跳转至行尾
```

#### 行间移动
```bash
'#'G 或者扩展命令模式下 
:'#'   跳转至由第'#'行
G 最后一行
1G, gg 第一行
```

#### 翻页
```bash
Ctrl+f 向文件尾部翻一屏,相当于Pagedown
Ctrl+b 向文件首部翻一屏,相当于Pageup
Ctrl+d 向文件尾部翻半屏
Ctrl+u 向文件首部翻半屏
```

#### 字符编辑
```bash
x 剪切光标处的字符
'#'x 剪切光标处起始的#个字符
xp 交换光标所在处的字符及其后面字符的位置
~ 转换大小写
J 删除当前行后的换行符
```

#### 替换命令
```bash
r 只替换光标所在处的一个字符
R 切换成REPLACE模式（在末行出现-- REPLACE -- 提示）,按ESC回到命令模式
:%s/1/2/g 将所有的1替换为2
```

#### 删除命令
```bash
d 删除命令，可结合光标跳转字符，实现范围删除
d$ 删除到行尾
d^ 删除到非空行首
d0 删除到行首
dw
de
db
'#'COMMAND
dd：   剪切光标所在的行
'#'dd 多行删除
D：从当前光标位置一直删除到行尾，等同于d$
```

#### 复制命令
```bash
y 复制，行为相似于d命令
y$
y0
y^
ye
yw
yb
'#'COMMAND
yy：复制行
'#'yy 复制多行
Y：复制整行
```

#### 粘贴命令
```bash
p 缓冲区存的如果为整行，则粘贴当前光标所在行的下方；否则，则粘贴至当前光标所在处的后面
P 缓冲区存的如果为整行，则粘贴当前光标所在行的上方；否则，则粘贴至当前光标所在处的前面
```

#### 查找
```bash
/PATTERN：从当前光标所在处向文件尾部查找
?PATTERN：从当前光标所在处向文件首部查找
n：与命令同方向
N：与命令反方向
```

#### 撤销更改
```bash
u 撤销最近的更改，相当于windows中ctrl+z
'#'u 撤销之前多次更改
U 撤消光标落在这行后所有此行的更改
Ctrl-r 重做最后的“撤消”更改，相当于windows中crtl+y
. 重复前一个操作
'#'. 重复前一个操作'#'次
```

#### 多文件模式
```bash
vim FILE1 FILE2 FILE3 ...
:next 下一个
:prev 前一个
:first 第一个
:last 最后一个
:wall 保存所有
:qall 不保存退出所有
:wqall保存退出所有
```

#### 多文件分割
```bash
vim -o|-O FILE1 FILE2 ...
-o: 水平或上下分割
-O: 垂直或左右分割（vim only）
在窗口间切换：Ctrl+w, Arrow
```

#### 单文件窗口分割
```bash
Ctrl+w,s：split, 水平分割，上下分屏
Ctrl+w,v：vertical, 垂直分割，左右分屏
ctrl+w,q：取消相邻窗口
ctrl+w,o：取消全部窗口
:wqall 退出
```

<div align=center><img src="vim-keymap.png"></div>

### 文本查看

#### cat
- -E：显示行结束符$
- -A：显示所有控制符
- -n：对显示出的每一行进行编号
- -b：非空行编号
- -s：压缩连续的空行成一行
```bash
cat -n test
```

#### head
- -c # 指定获取前#字节
- -n # 指定获取前#行,#如果为负数,表示从文件头取到倒数第#前
- -# 同上
```bash
head -n -3 test
```

#### tail
- -c # 指定获取后#字节
- -n # 指定获取后#行,如果#是负数,表示从第#行开始到文件结束
- -# 同上
- -f 跟踪显示文件fd新追加的内容,常用日志监控，相当于 --follow=descriptor,当文件删除再新建同名文件,将无法继续跟踪文件
- -F 跟踪文件名，相当于--follow=name --retry，当文件删除再新建同名文件,将可以继续跟踪文件
```bash
tail -10 test
tail -f nginx.log
```

#### more less
```bash
# more可以实现分页查看文件
more test

# less也可以实现分页查看文件，但是它有搜索功能，和vim类似，比较好用
cat test | less
```

### 文本分割合并

#### cut
- -d DELIMITER: 指明分隔符，默认tab
- -f FILEDS:
    -  #: 第#个字段,例如:3
    -  #,#[,#]：离散的多个字段，例如:1,3,6
    -  #-#：连续的多个字段, 例如:1-6
    -  混合使用：1-3,7
- -c 按字符切割
- --output-delimiter=STRING指定输出分隔符
```bash
echo a-b-c-d | cud -d- -f1,3
```

#### paste
- -d  #分隔符：指定分隔符，默认用TAB
- -s  #所有行合成一行显示
```bash
paste -d: alpha.log seq.log
paste -s -d: title.txt emp.txt
```

### 分析文本

#### wc
- -l 只计数行数
- -w 只计数单词总数
- -c 只计数字节总数
- -m 只计数字符总数
- -L 显示文件中最长行的长度
```bash
wc -l test
```

#### sort
- -r 执行反方向（由上至下）整理
- -R 随机排序
- -n 执行按数字大小整理
- -h 人类可读排序,如: 2K 1G 
- -f 选项忽略（fold）字符串中的字符大小写
- -u 选项（独特，unique），合并重复项，即去重
- -t , 选项使用,做为字段界定符
- -k# 选项按照使用,字符分隔的 # 列来整理能够使用多次
```bash
sort -t, -k2 -nr tmp 
```

#### uniq
- -c: 显示每行重复出现的次数
- -d: 仅显示重复过的行
- -u: 仅显示不曾重复的行
```bash
uniq -c tmp2 | sort -t' ' -k1 -nr | tr -s ' ' ',' | cut -d, -f3  # 一列字母按出现次数降序
```

#### diff patch
```bash
# diff比较两个文件之间的差别
# -u 选项来输出“统一的（unified）”diff格式文件
diff -u f1.txt f2.txt

# patch复制在其它文件中进行的改变
# -b 选项来自动备份改变了的文件
diff -u foo.conf foo2.conf > foo.patch 
patch -b foo.conf foo.patch

# vimdiff，相当于vim -d，在vim中比较两个文件的差别
vimdiff f1.txt f2.txt  
```

### 文本模式匹配grep
grep [OPTIONS] PATTERN [FILE...]
- -color=auto 对匹配到的文本着色显示
- -m  # 匹配#次后停止
- -v 显示不被pattern匹配到的行,即取反
- -i 忽略字符大小写
- -n 显示匹配的行号
- -c 统计匹配的行数
- -o 仅显示匹配到的字符串
- -q 静默模式，不输出任何信息
- -A # after, 后#行
- -B # before, 前#行
- -C # context, 前后各#行
- -e 实现多个选项间的逻辑or关系,如：grep –e ‘cat ' -e ‘dog' file
- -w 匹配整个单词
- -E 使用ERE，相当于egrep
- -F 不支持正则表达式，相当于fgrep
- -f file 根据模式文件处理
- -r   递归目录，但不处理软链接
- -R   递归目录，但处理软链接
```bash
grep -f /data/f1.txt /data/f2.txt  # 返回两个文件相同的部分
ifconfig eth0 | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}'|head -1  # 返回rth0网卡的IP地址
```

### 行编辑器sed

sed 即 Stream EDitor，和 vi 不同，sed是行编辑器。Sed是从文件或管道中读取一行，处理一行，输出一行；直到最后一行。每当处理一行时，把当前处理的行存储在临时缓冲区中，称为模式空间（Pattern Space），接着用sed命令处理缓冲区中的内容，处理完成后，把缓冲区的内容送往屏幕。接着处理下一行，这样不断重复，直到文件末尾。一次处理一行的设计模式使得sed性能很高，相比vim一次性将文件加载到内存效率更高。

`sed [option]... 'script;script;...' [inputfile...]`，sed [可选参数] '位置 命令' 输入文件
#### option
- -n 不输出模式空间内容到屏幕，即不自动打印
- -e 多点编辑
- -f FILE 从指定文件中读取编辑脚本
- -r, -E 使用扩展正则表达式
- -i.bak 备份文件并原处编辑
- -s           将多个文件视为独立文件，而不是单个连续的长文件流
- #说明: 
- -ir 不支持
- -i -r 支持
- -ri   支持
- -ni   会清空文件

#### script
script是地址，不指定地址则对全文进行处理
- 单地址：
    - #：指定的行，$：最后一行
    - /pattern/：被此处模式所能够匹配到的每一行
- 地址范围：
    - #,#     #从#行到第#行，3，6 从第3行到第6行
    - #,+#   #从#行到+#行，3,+4 表示从3行到第7行
    - /pat1/,/pat2/
    - #,/pat/
    - /pat/,#
- 步进：~
    - 1~2 奇数行
    - 2~2 偶数行

#### 命令
- p 打印当前模式空间内容，追加到默认输出之后
- Ip 忽略大小写输出
- d 删除模式空间匹配的行，并立即启用下一轮循环
- a [\\]text 在指定行后面追加文本，支持使用\n实现多行追加
- i [\\]text 在行前面插入文本
- c [\\]text 替换行为单行或多行文本
- w file 保存模式匹配的行至指定文件
- r file 读取指定文件的文本至模式空间中匹配到的行后
- = 为模式空间中的行打印行号
- ! 模式空间中匹配行取反处理
- q 结束或退出sed

#### 查找替换
- s/pattern/string/修饰符 查找替换,支持使用其它分隔符，可以是其它形式：s@@@，s###
- 替换修饰符：
- g 行内全局替换
- p 显示替换成功的行
- w   /PATH/FILE 将替换成功的行保存至文件中
- I,i   忽略大小写

```bash
 echo ab-cd | sed -n 's/-/,/gp'  # 替换并打印结果
 ifconfig eth0 | sed -n '2p'  # 打印网卡信息的第二行
 sed -n '$p' /etc/passwd  # 打印指定文件最后一行
 sed -n "$(echo $[`cat /etc/passwd|wc -l`-1])p" /etc/passwd  # 打印倒数第二行
 ifconfig eth0 |sed -n '/inet*/p'  # 打印匹配到的行
 seq 10 | sed -n '3,+4p'  # 第三行到第七行
 seq 10 | sed '2~2d'  # 删除偶数
 sed  '/^$/d' test  # 删除空行
 seq 10 | sed -e '2d' -e '4d'  # 多点编辑，这样也可以：sed '2d;4d'
 sed '/^#/d;/^$/d' test  # 不显示注释和空行，这样也可以：grep -Ev '^#|^$'
 sed -i.bak '2d;4d' test  # 把原文件备份为test.bak并对原文件原地修改
 seq 10 | sed '2,3a tea'  # 在指定的行后添加内容
 # 提取IP地址的几种方法
 ifconfig eth0 | sed -n '2s/.*inet //g;s/ netmask.*//gp'
 ifconfig eth0 | sed -nr "2s/[^0-9]+([0-9.]+).*/\1/p"
 ifconfig eth0 | sed -rn '2s/(.*inet )([0-9].*)( netmask.*)/\2/p'
 echo a.b.c.gz |sed -En 's/(.*)\.([^.]+)$/\1/p'  # 取文件前缀
 echo a.b.c.gz |sed -En 's/(.*)\.([^.]+)$/\2/p'  # 取文件后缀
 echo /etc/sysconfig/ | sed -rn 's#(.*)/([^/]+)/?#\1#p'  # 取目录名
 echo /etc/sysconfig/ | sed -rn 's#(.*)/([^/]+)/?#\2#p'  # 取基名
```

### AWK文本处理

#### awk工作过程

- 第一步：执行BEGIN{action;… }语句块中的语句
- 第二步：从文件或标准输入(stdin)读取一行，然后执行pattern{ action;… }语句块，它逐行扫描文件，从第一行到最后一行重复这个过程，直到文件全部被读取完毕。
- 第三步：当读至输入流末尾时，执行END{action;…}语句块BEGIN语句块在awk开始从输入流中读取行之前被执行，这是一个可选的语句块，比如变量初始化、打印输出表格的表头等语句通常可以写在BEGIN语句块中

END语句块在awk从输入流中读取完所有的行之后即被执行，比如打印所有行的分析结果这类信息汇总都是在END语句块中完成，它也是一个可选语句块

pattern语句块中的通用命令是最重要的部分，也是可选的。如果没有提供pattern语句块，则默认执行{print}，即打印每一个读取到的行，awk读取的每一行都会执行该语句块

```bash
# awk [options]   'program' var=value   file…
# awk [options]   -f programfile    var=value file…
```

#### print
```bash
seq 10 | awk '{print $1,"hello"}'
awk -F: '{print $1"\t"$3}' /etc/passwd
ifconfig eth0 | awk '/netmask/{print $2}'  # 查看ip，/pattern/是匹配pattern所在行
echo "1 www.baidu.com" | awk -F "[ .]" '{print $3}'  # 正则表达式分割
```

#### 变量
内部变量
- FS：输入字段分隔符，默认为空白字符，相当于-F
- OFS：输出字段分隔符，默认为空白字符
- RS：输入记录分隔符，指定输入时的换行符
- ORS：输出记录分隔符，使用指定字符代替输出换行符
- NF：字段数量
- NR：记录编号
- FNR：各文件分别计数，记录的编号
- FILENAME：当前文件名
- ARGC：命令行参数的个数
- ARGV：数组，保存的是命令行给定的各参数，每一个参数ARGV[0]....

```bash
awk -v FS=':' '{print $1,FS,$3}' /etc/passwd
awk -F: -v OFS='-' '{print $1,$3}' /etc/passwd
awk -v RS=' ' '{print }' /etc/passwd
awk -v RS=' ' -v ORS='###' '{print $0}' /etc/passwd
awk -F: '{print NF}' /etc/passwd
awk -F: '{print $(NF-1)}' /etc/passwd
awk '{print NR,$0}' /etc/issue /etc/centos-release
awk '{print FNR,$0}' /etc/issue /etc/centos-release
awk '{print ARGC}' /etc/issue /etc/redhat-release
awk '{print ARGV[0]}' /etc/issue /etc/redhat-release
```

自定义变量

可以使用v操作符也可以在代码块中直接定义
```bash
awk -v test1=test2="hello awk" 'BEGIN{print test1,test2}'  # 注意赋值结果和在代码块中的结果不相同
awk 'BEGIN{test1=test2="hello awk";print test1,test2}'
```

#### printf
printf "FORMAT", item1, item2

- 注意必须指定FORMAT；不会自动换行；FORMAT需要分别为后面每个item指定格式符号
- %s：显示字符串
- %d, %i：显示十进制整数
- %f：显示为浮点数
- %e, %E：显示科学计数法数值 
- %c：显示字符的ASCII码
- %g, %G：以科学计数法或浮点形式显示数值
- %u：无符号整数
- %%：显示%自身
- #[.#] 第一个数字控制显示的宽度；第二个#表示小数点后精度，如：%3.1f
- - 左对齐（默认右对齐） 如：%-15s
- +   显示数值的正负符号   如：%+d

```bash
awk -F: '{printf "%s\n",$1}' /etc/passwd
awk -F: '{printf "%20s\n",$1}' /etc/passwd
awk -F: '{printf "%-20s %10d\n",$1,$3}' /etc/passwd
awk -F: '{printf "USERname: %-20s UID:%-10d\n",$1,$3}' /etc/passwd
```

#### 操作符
算数操作符

x+y, x-y, x*y, x/y, x^y, x%y；-x：转换为负数；+x：将字符串转换为数值

字符串操作

=, +=, -=, *=, /=, %=, ^=，++, --

比较操作符

==, !=, >, >=, <, <=

逻辑操作符

&& 与；|| 或；! 非

条件表达式

selector?if-true-expression:if-false-expression

```bash
awk 'BEGIN{i=0;print i++,i}'
seq 10 | awk 'n++'
awk -v n=0 '!n++{print n}' /etc/passwd  # 取n++的非
awk 'NR==2' /etc/issue
awk -F: '$3>=1000' /etc/passwd
seq 10 | awk 'NR%2==0'  # 取奇偶行
awk 'BEGIN{print !i}'
awk -F: '$3>=0 && $3<=1000 {print $1,$3}' /etc/passwd
awk -F: '{$3>=1000?usertype="Common User":usertype="SysUser";printf "%-20s:%12s\n",$1,usertype}' /etc/passwd  # 三目表达式
```

#### 模式匹配
根据pattern条件过滤匹配的行再做处理

```bash
awk '/^UUID/{print $1}' /etc/fstab
df | awk '/^\/dev\//'  # 以/dev/开头的行
seq 10 | awk '1'  # 结果为非0值或非空字符串为真
seq 10 | awk '0'  # 结果为空字符串或0值为假
seq 10 | awk 'NR>=3 && NR<=6'  # 获取行范围
awk -F: 'BEGIN{print "USER USERID\n-----"} {print $1":"$3} END{print "-----\nEND FILE"}' /etc/passwd  # BEGIN和END分别只在开始和结尾运行
awk -F: 'BEGIN{printf "--------------------------------\n%-20s|%10s|\n--------------------------------\n","username","uid"}{printf "%-20s|%10d|\n--------------------------------\n",$1,$3}' /etc/passwd
```

#### 条件和循环
```bash
# if-else
awk -F: '{if($3<=100){print "<=100",$3}else if ($3<=1000) {print "<=1000",$3} else{print ">=1000",$3}}' /etc/passwd
# while循环
awk -v n=0 -v sum=0 'BEGIN{while(n<=100){sum+=n;n++};print sum}'
awk 'BEGIN{sum=0;n=0;while(n<=100){sum+=n;n++};print sum}'
# do-while
awk 'BEGIN{sum=0;n=0;do{sum+=n;n++}while(n<=100);print sum}'
# for循环
awk 'BEGIN{sum=0;for(i=1;i<=100;i++){sum+=i};print sum}'
for (( i=1,sum=0;i<=100;i++ ));do let sum+=i;done;echo $sum
# continue和break
awk 'BEGIN{for(i=1;i<=100;i++){if(i==50)continue;sum+=i};print sum}'
awk 'BEGIN{for(i=1;i<=100;i++){if(i==50)break;sum+=i};print sum}'
# next提前结束对本行的处理进入下一行处理
seq 10 | awk '{if($1%2==1) next; print $1}'
```

#### 数组
```bash
# 判断数组元素是否存在
awk 'BEGIN{array["i"]="x"; array["j"]="y" ; print "i" in array, "y" in array }'
# 遍历数组
awk 'BEGIN{weekdays["mon"]="Monday";weekdays["tue"]="Tuesday";for(i in weekdays){print i,weekdays[i]}}'
awk -F: '{user[$1]=$3}END{for (i in user){printf "%15s %10d\n" "User: ",i,user[i] /etc/passwd
```

#### awk函数
内置函数
- rand() 返回0和1之间一个随机数
- srand() 配合rand()函数生成随机数的种子
- int() 返回整数
- length([s]) 返回指定字符串的长度
- sub(r,s,[t]) 对t字符串搜索r表示模式匹配的内容，并将第一个匹配内容替换为s
- gsub(r,s,[t]) 对t字符串搜索r表示模式匹配的内容，并将所有的匹配内容替换为s
- split(s,array,[r]) 以r为分隔符切割字符串s，并将结果保存到array数组中
- system('cmd') 调用shell命令
- systime() 10位时间戳
- strftime() 指定时间格式

```bash
awk 'BEGIN{srand(); for(i=1;i<=10;i++){print int(rand()*100)}}'  # 10个0-100随机数
cut -d: -f1 /etc/passwd | awk '{print length()}'  # 返回字符串长度
awk -F: '{print length($1)}' /etc/passwd
echo "2008:08:08 08:08:08" | awk 'sub(/:/,"-",$1)'  # 替换第一个
echo "2008:08:08 08:08:08" | awk 'gsub(/:/,"-",$0)'  # 替换所有
awk 'BEGIN{system("pwd")}'  # 执行命令
awk 'BEGIN{print systime()}'  # 10位时间戳
awk 'BEGIN{print strftime("%Y-%m-%d %H:%M%S")}'  # 当前时间格式化
awk 'BEGIN{print strftime("%Y-%m-%d %H:%M%S", systime()-3600)}'  # 指定时间戳格式化
```

自定义函数

将程序写为脚本，通过-f参数直接使用，通过-v传递参数
```bash
cat << EOF > func.awk 
function max(x,y) {
    x>y?var=x:var=y
    return var
}
BEGIN{print max(a,b)}
EOF
awk -v a=30 -v b=20 -f func.awk 
```

## 软件包管理
主流的软件包管理器：
- redhat：rpm文件, rpm 包管理器，rpm：Redhat Package Manager，RPM Package Manager 
- debian：deb文件, dpkg 包管理器

### 包的依赖
软件包之间可能存在依赖关系，甚至循环依赖，即：A包依赖B包，B包依赖C包，C包依赖A包安装软件包时，会因为缺少依赖的包，而导致安装包失败。

解决依赖包管理工具：
- yum：rpm包管理器的前端工具
- dnf：Fedora 18+ rpm包管理器前端管理工具，CentOS 8 版代替 yum
- apt：deb包管理器前端工具
- zypper：suse上的rpm前端管理工具

### 获取程序包
官方网站
```bash
CentOS镜像：
https://www.centos.org/download/
Ubuntu镜像：
http://cdimage.ubuntu.com/releases/
http://releases.ubuntu.com
```

软件项目官方网站点
```bash
http://yum.mariadb.org/10.4/centos8-amd64/rpms/
http://repo.mysql.com/yum/mysql-8.0-community/el/8/x86_64/
```

搜索引擎
```bash
http://pkgs.org
http://rpmfind.net
http://rpm.pbone.net
https://sourceforge.net/
```

### RPM包管理
#### 安装
rpm {-i|--install} [install-options] PACKAGE_FILE… 
- -v --verbose
- -h 以#显示程序包管理执行进度
- --test: 测试安装，但不真正执行安装，即dry run模式
- --nodeps：忽略依赖关系
- --replacepkgs | replacefiles
- --nosignature: 不检查来源合法性
- --nodigest：不检查包完整性
- --noscripts：不执行程序包脚本
    - %pre: 安装前脚本 --nopre
    - %post: 安装后脚本 --nopost
    - %preun: 卸载前脚本 --nopreun
    - %postun: 卸载后脚本 --nopostun
```bash
rpm -ivh PACKAGE_FILE...
```

#### 升级和降级
rpm {-U|--upgrade} [install-options] PACKAGE_FILE...

rpm {-F|--freshen} [install-options] PACKAGE_FILE...

upgrade：安装有旧版程序包，则"升级"，如果不存在旧版程序包，则"安装"

freshen：安装有旧版程序包，则"升级"， 如果不存在旧版程序包，则不执行升级操作

--oldpackage：降级

--force: 强制安装

```bash
rpm -Uvh PACKAGE_FILE ...
rpm -Fvh PACKAGE_FILE ...
```

#### 包查询
rpm {-q|--query} [select-options] [query-options]

[select-options]
- -a：所有包
- -f：查看指定的文件由哪个程序包安装生成
- -p rpmfile：针对尚未安装的程序包文件做查询操作
[query-options]
- --changelog：查询rpm包的changelog
- -c：查询程序的配置文件
- -d：查询程序的文档
- -i：information
- -l：查看指定的程序包安装后生成的所有文件
- --scripts：程序包自带的脚本
- --whatprovides CAPABILITY：查询指定的CAPABILITY由哪个包所提供
- --whatrequires CAPABILITY：查询指定的CAPABILITY被哪个包所依赖
- --provides：列出指定程序包所提供的CAPABILITY
- -R：查询指定的程序包所依赖的CAPABILITY

#### 包卸载
rpm {-e|--erase} [--allmatches] [--nodeps] [--noscripts] [--notriggers] [--test] PACKAGE_NAME ...

### yum和dnf
yum/dnf是基于C/S模式，yum服务端存放rpm包和相关包的元数据，yum客户端访问服务端进行安装或查询

#### yum配置文件
```bash
/etc/yum.conf #为所有仓库提供公共配置
/etc/yum.repos.d/*.repo： #为每个仓库的提供配置文件
```

yum配置文件定义
```conf
[repositoryID]
name=Some name for this repository
baseurl=url://path/to/repository/  # file://, http://, https://, ftp://
enabled={1|0}
gpgcheck={1|0}  # 安装包前要做包的合法和完整性校验
gpgkey=URL
enablegroups={1|0}
failovermethod={roundrobin|priority}
 roundrobin：意为随机挑选，默认值
 priority:按顺序访问
cost= 默认为1000
```

yum的repo配置文件中可用的变量：
```bash
$releasever  # 当前OS的发行版的主版本号，如：8，7，6
$arch  # CPU架构，如：aarch64, i586, i686，x86_64等
$basearch  # 系统基础平台；i386, x86_64
$contentdir  # 表示目录，比如：centos-8，centos-7
$YUM0-$YUM9  # 自定义变量
```

阿里云提供了写好的CentOS和ubuntu的仓库文件
```bash
http://mirrors.aliyun.com/repo/
```

常用国内yum源
```bash
# CentOS系统的yum源
#阿里云
https://mirrors.aliyun.com/centos/$releasever/
#腾讯云
https://mirrors.cloud.tencent.com/centos/$releasever/
#华为云
https://repo.huaweicloud.com/centos/$releasever/
#清华大学
https://mirrors.tuna.tsinghua.edu.cn/centos/$releasever/

# EPEL的yum源
#阿里云
https://mirrors.aliyun.com/epel/$releasever/x86_64
#腾讯云
https://mirrors.cloud.tencent.com/epel/$releasever/x86_64
#华为云
https://mirrors.huaweicloud.com/epel/$releasever/x86_64
#清华大学
https://mirrors.tuna.tsinghua.edu.cn/epel/$releasever/x86_64
```

#### yum-config-manager
可以生成yum仓库的配置文件及启用或禁用仓库，来自于yum-utils包

```bash
yum-config-manager --add-repo "URL或file"  # 增加仓库
yum-config-manager --disable "仓库名"  # 禁用仓库
yum-config-manager --enable  "仓库名"  # 启用仓库

# 创建仓库配置
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum-config-manager --add-repo /data/docker-ce.repo

# 启用/禁用repo
yum-config-manager --disable extras
yum-config-manager --enable extras
```

#### yum命令
yum [options] [command] [package ...]
- -y 自动回答为"yes"
- -q 静默模式
- --nogpgcheck 禁止进行gpg check
- --enablerepo=repoidglob 临时启用此处指定的repo，支持通配符，如："*"
- --disablerepo=repoidglob 临时禁用此处指定的repo,和上面语句同时使用，放在后面的生效

显示仓库列表
```bash
yum repolist
yum repolist --disebaled  # 查看已停用的仓库
yum repolist -v  # 显示仓库的详细信息
```

显示程序包
```bash
yum list  # 查看所有程序包
yum list mariadb-server  # 显示制定的rpm包
yum list exim*  # 支持通配符
yum list installed  # 只显示已安装的包
yum list available  # 显示可安装的包
yum list updates  # 显示可以升级的包
```

安装程序包
```bash
yum install package1 [package2] [...]
yum reinstall package1 [package2] [...]  #重新安装
--downloadonly  #只下载相关包默认至/var/cache/yum/x86_64/7/目录下,而不执行install/upgrade/erase 
--downloaddir=<path>, --destdir=<path>  #--downloaddir选项来指定下载的目录,如果不存在自动创建
yum -y install --downloadonly --downloaddir=/data/httpd httpd
```

卸载程序包
```bash
yum remove | erase package1 [package2] [...]
```

升级和降级
```bash
yum upgrade|update [package1] [package2] [...]
yum upgrade-minimal   #最小化升级
yum downgrade package1 [package2] [...]  # 降级
```

查询搜索
```bash
yum info mariadb-server  # 查询程序包信息
yum deplist mariadb-server  # 查看依赖关系
yum search mysql*  # 模糊查询程序包
```

仓库缓存
```bash
du -sh /var/cache/yum  # 查看缓存大小，有时候可能是dnf
yum makecache  # 构建缓存
yum clean all  # 清除所有缓存
```

yum日志
```bash
# CentOS 7以前版本日志
/var/log/yum.log
# CentOS 8 版本日志
/var/log/dnf.rpm.log
/var/log/dnf.log

yum history  # 查看历史命令
yum history info 22  # 查看指定id的历史命令详细信息
yum history undo 22 -y  # 撤销
yum history redo 22 -y  # 重新运行
```

#### dnf
在 RHEL 8.0 版本正式取代了 YUM，DNF包管理器克服了YUM包管理器的一些瓶颈，提升了包括用户体验，内存占用，依赖分析，运行速度等。用法和yum基本相同
```bash
# 配置文件
/etc/dnf/dnf.conf
# 仓库文件
/etc/yum.repos.d/ *.repo
# 日志文件
/var/log/dnf.rpm.log
/var/log/dnf.log
```

## 程序包编译
### C语言编译过程
- ./configure
    - 通过选项传递参数，指定安装路径、启用特性等；执行时会参考用户的指定以及Makefile.in文件生成Makefile
    - 检查依赖到的外部环境，如依赖的软件包
- make 根据Makefile文件，会检测依赖的环境，进行构建应用程序
- make install 复制文件到相应路径

### 编译安装准备
- 开发工具：make, gcc (c/c++编译器GNU C Complier)
- 开发环境：开发库（glibc：标准库），头文件，可安装开发包组 Development Tools
- 软件相关依赖包

建议安装相关包
```bash
yum install gcc make autoconf gcc-c++ glibc glibc-devel pcre pcre-devel openssl openssl-devel systemd-devel zlib-devel  vim lrzsz tree tmux lsof tcpdump wget net-tools iotop bc bzip2 zip unzip nfs-utils man-pages
```

### 编译安装
1. 运行 configure 脚本，生成 Makefile 文件。可以指定安装位置，指定启用的特性
```bash
# 安装路径设定
--prefix=/PATH  # 指定默认安装位置,默认为/usr/local/
--sysconfdir=/PATH  # 配置文件安装位置
# 软件特性和相关指定
Optional Features: 可选特性
 --disable-FEATURE
 --enable-FEATURE[=ARG]
Optional Packages: 可选包
 --with-PACKAGE[=ARG] 依赖包
 --without-PACKAGE 禁用依赖关系
# 注意：通常被编译操作依赖的程序包，需要安装此程序包的"开发"组件，其包名一般类似于name-devel-VERSION
```
2. make
3. make install

### 编译安装httpd
```bash
# 安装相关包
dnf install gcc make autoconf apr-devel apr-util-devel pcre-devel openssl-devel redhat-rpm-config
# 下载并解压包
wget https://mirror.bit.edu.cn/apache//httpd/httpd-2.4.46.tar.bz2
tar xvf httpd-2.4.46.tar.bz2 -C /usr/local/src
# 配置
cd /usr/local/src/httpd-2.4.43/
./configure --prefix=/apps/httpd --sysconfdir=/etc/httpd --enable-ssl
# 编译安装
make -j 4 && make install 
# 配置环境，也可以加入PATH或者软链接到/usr/bin
echo 'PATH=/apps/httpd/bin:$PATH' > /etc/profile.d/httpd.sh
. /etc/profile.d/httpd.sh
# 运行
apachectl start
```

## Ubuntu软件管理

- dpkg：package manager for Debian，类似于rpm， dpkg是基于Debian的系统的包管理器。可以安装，删除和构建软件包，但无法自动下载和安装软件包或其依赖项
- apt：Advanced Packaging Tool，功能强大的软件管理工具，甚至可升级整个Ubuntu的系统，基于客户/服务器架构，类似于yum

### dpkg包管理
```bash
#安装包
dpkg -i package.deb 
#删除包，不建议，不自动卸载依赖于它的包
dpkg -r package 
#删除包（包括配置文件）
dpkg -P package 
#列出当前已安装的包，类似rpm -qa
dpkg -l
#显示该包的简要说明
dpkg -l package 
#列出该包的状态，包括详细信息，类似rpm –qi
dpkg -s package 
#列出该包中所包含的文件，类似rpm –ql 
dpkg -L package 
#搜索包含pattern的包，类似rpm –qf 
dpkg -S <pattern> 
#配置包，-a 使用，配置所有没有配置的软件包
dpkg --configure package 
#列出 deb 包的内容，类似rpm –qpl 
dpkg -c package.deb 
#解开 deb 包的内容
dpkg --unpack package.deb 
```
注意：一般建议不要使用dpkg卸载软件包。因为删除包时，其它依赖它的包不会卸载，并且可能无法再正常运行

### apt

之前最常用的 Linux 包管理命令都被分散在了 apt-get、apt-cache 和 apt-config 这三条命令中。

Ubuntu 16.04 引入新特性之一便是 apt 命令，apt 命令解决了命令过于分散的问题，它包括 apt-get 命令出现以来使用最广泛的功能选项，以及 apt-cache 和 apt-config 命令中很少用到的功能。在使用apt 命令时，用户不必再由 apt-get 转到 apt-cache 或 apt-config，提供管理软件包所需的必要选项。

apt配置文件
```bash
/etc/apt/sources.list
/etc/apt/sources.list.d

# 修改为清华源
sed -i 's/mirrors.aliyun.com/mirrors.tuna.tsinghua.edu.cn/' /etc/apt/sources.list
```

常用命令
```bash
#安装包：
apt install tree zip
#安装图形桌面
apt install ubuntu-desktop
#删除包：
apt remove tree zip
#说明：apt remove中添加--purge选项会删除包配置文件，谨慎使用
#更新包索引，相当于yum clean all;yum makecache
apt update  
#升级包：要升级系统，请首先更新软件包索引，再升级
apt upgrade
#apt列出仓库软件包，等于yum list
apt list
#搜索安装包
apt search nginx
#查看某个安装包的详细信息
apt show apache2 
#在线安装软件包
apt install apache2 
#卸载单个软件包但是保留配置⽂件
apt remove apache2 
#删除安装包并解决依赖关系
apt autoremove apache2 
#更新本地软件包列表索引，修改了apt仓库后必须执⾏
apt update 
#卸载单个软件包删除配置⽂件
apt purge apache2 
#升级所有已安装且可升级到新版本的软件包
apt upgrade
#升级整个系统，必要时可以移除旧软件包。
apt full-upgrade 
#编辑source源⽂件
apt edit-sources 
#查看仓库中软件包有哪些版本可以安装
apt-cache madison nginx 
#安装软件包的时候指定安装具体的版本
apt install nginx=1.14.0-0ubuntu1.6 
#查看文件来自于哪个包,类似redhat中的yum provides <filename>
apt-file search 'string'  #默认是包含此字符串的文件
apt-file search -x  '正则表达式'
apt-file search -F /path/file
```