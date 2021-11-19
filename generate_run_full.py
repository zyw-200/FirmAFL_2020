import os
import sys

def generate_run_full(image_id, arch):
	script_src = "firmadyne/scratch/%s/run.sh" %image_id
	script_dst = "firmadyne/scratch/%s/run_full.sh" %image_id
	file_src = open(script_src)
	file_dst = open(script_dst, "w+")
	remove_flag = 0
	for line in file_src.readlines():
		if remove_flag == 1:
			remove_flag = 0
		elif "sleep 1s" in line:
			file_dst.write(line)
			archh = arch
			if cmp(arch, "mipseb") == 0:
				archh = "mips"
			elif cmp(arch, "armel") == 0:
				archh = "arm"
			newline_0 = "QEMU=./qemu-system-%s\n" %archh
			if cmp(archh, "mipsel") == 0 or cmp(archh, "mips") == 0:
				newline_1 = "KERNEL='./vmlinux.%s_3.2.1'\n" %archh
			elif cmp(archh, "arm") == 0:
				newline_1 = "KERNEL='./zImage.armel'\n"
			else:
				newline_1 = ""
			newline_2 = "IMAGE='./image.raw'\n"
			newline1 = "AFL=\"./afl-fuzz-full -m none -t 800000+  -i ./inputs -o ./outputs_full -x keywords -QQ -- \"\n"
			newline2 = "${AFL} "
			file_dst.write(newline_0)
			file_dst.write(newline_1)
			file_dst.write(newline_2)
			file_dst.write(newline1)
			file_dst.write(newline2)
			remove_flag = 1 #next line should be removed
		elif "QEMU_AUDIO_DRV=none" in line:
			new_line = line.replace("QEMU_AUDIO_DRV=none", "")
			file_dst.write(new_line)
		elif "tee" in line:
			new_line = line.split("|")[0] + "\\\n"
			file_dst.write(new_line)
		else:
			file_dst.write(line)
	file_dst.write("	-aflFile @@ \n")
	file_src.close()
	file_dst.close()
	chmod_str = "chmod 777 %s" %script_dst
	os.system(chmod_str)


#single

image_id = sys.argv[1]	
arch = sys.argv[2]
generate_run_full(image_id, arch)

'''
fp = open("testlist")
for line in fp.readlines():
	array = line.split(":")
	image_id = array[0].strip()
	generate_run_full(image_id)
fp.close()
'''