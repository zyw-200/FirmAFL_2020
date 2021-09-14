import sys
import os

firm_id = sys.argv[1]
firm_arch = sys.argv[2]
firm_dir = "image"+firm_id

os.system("echo core >/proc/sys/kernel/core_pattern")
os.system("cd /sys/devices/system/cpu\necho performance | tee cpu*/cpufreq/scaling_governor\ncd -")

cmd = "python generate_run_full.py %s %s" %(firm_id, firm_arch)
os.system(cmd)
sys_run_src = "firmadyne/scratch/%s/run_full.sh" %(firm_id)
user_run_src = "FirmAFL_config/%s/user.sh" %firm_id
if "mips" in firm_arch:
	sys_src = "qemu_mode/DECAF_qemu_2.10/%s-softmmu/qemu-system-%s" %(firm_arch, firm_arch)
	user_src = "user_mode/%s-linux-user/qemu-%s" %(firm_arch, firm_arch)
else:
	sys_src = "qemu_mode/DECAF_qemu_2.10/arm-softmmu/qemu-system-arm"
	user_src = "user_mode/arm-linux-user/qemu-arm" 
config_src = "FirmAFL_config/%s/FirmAFL_config" %(firm_id)
test_src = "FirmAFL_config/%s/test.py" %(firm_id)
keywords_src = "FirmAFL_config/%s/keywords" %(firm_id)
afl_src= "FirmAFL_config/afl-fuzz-full"
firmadyne_src = "firmadyne/firmadyne.config"
image_src = "firmadyne/scratch/%s/image.raw" %firm_id
if "mips" in firm_arch:
	kernel_src ="firmadyne_modify/vmlinux.%s_3.2.1" %firm_arch
else:
	kernel_src ="firmadyne_modify/zImage.armel"
procinfo_src =  "FirmAFL_config/procinfo.ini"
other_file1 =  "FirmAFL_config/efi-pcnet.rom"
other_file2 =  "FirmAFL_config/vgabios-cirrus.bin"
cmd_input = "mkdir image_%s/inputs" %firm_id
seed_src = "FirmAFL_config/%s/seed" %(firm_id)
start_src = "FirmAFL_config/start_full.py"

dst = "image_%s/" %firm_id
dst_input = "image_%s/inputs/" %firm_id

cmd = []
cmd.append("cp %s %s" %(sys_run_src, dst)) 
cmd.append("cp %s %s" %(user_run_src, dst)) 
cmd.append("cp %s %s" %(sys_src, dst)) 
cmd.append("cp %s %safl-qemu-trace" %(user_src, dst)) 
cmd.append("cp %s %s" %(config_src, dst)) 
cmd.append("cp %s %s" %(test_src, dst)) 
cmd.append("cp %s %s" %(keywords_src, dst)) 
cmd.append("cp %s %s" %(afl_src, dst)) 
cmd.append("cp %s %s" %(firmadyne_src, dst)) 
cmd.append("cp %s %s" %(image_src, dst)) 
cmd.append("cp %s %s" %(kernel_src, dst))
cmd.append("cp %s %s" %(procinfo_src, dst)) 
cmd.append("cp %s %s" %(other_file1, dst)) 
cmd.append("cp %s %s" %(other_file2, dst)) 
cmd.append(cmd_input)
cmd.append("cp %s %s" %(seed_src, dst_input)) 
cmd.append("cp %s %s" %(start_src, dst)) 

for i in range(0, len(cmd)):
	os.system(cmd[i])


if cmp(firm_id, "129780") == 0:
	os.system("cp FirmAFL_config/missing_file/129780/net.conf image_129780/var/config/")
	os.system("mkdir image_129780/var/run/")
	os.system("cp FirmAFL_config/missing_file/129780/profile.ini image_129780/var/run/")
	os.system("cp FirmAFL_config/missing_file/129780/video.ini image_129780/var/run/")
elif cmp(firm_id, "129781") == 0:
	os.system("cp FirmAFL_config/missing_file/129781/net.conf image_129781/var/config/")
	os.system("cp FirmAFL_config/missing_file/129781/net.conf image_129781/var/config/net.conf_ori")
elif cmp(firm_id, "10853") == 0:
	os.system("mkdir image_10853/var/run/")
	os.system("mkdir image_10853/var/etc/")
	os.system("cp FirmAFL_config/missing_file/10853/nvram.conf image_10853/var/etc/")
	os.system("cp FirmAFL_config/missing_file/10853/rc.pid image_10853/var/run/")
	os.system("cp FirmAFL_config/missing_file/10853/httpd.pid image_10853/var/run/")
elif cmp(firm_id, "161161") == 0:
	os.system("mkdir image_161161/tmp/etc/")
	os.system("cp FirmAFL_config/missing_file/161161/nvram.conf image_161161/tmp/etc/")
	os.system("cp FirmAFL_config/missing_file/161161/nvram_default_counter image_161161/tmp/etc/")
