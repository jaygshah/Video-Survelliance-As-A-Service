#!/usr/bin/python
import os
import sys
#weight_path = sys.argv[0]
#video_path = sys.argv[1]
obj = set()
#cmd = "./darknet detector demo cfg/coco.data cfg/yolov3-tiny.cfg "+ weight_path + " " + video_path + " -dont_show > result"
#os.system(cmd)
file_in = open("result", "r")
file_out = open("result_label","w")
for lines in file_in:
    if lines == "\n":
        continue
    if lines.split(":")[-1] == "\n":
        continue
    if lines.split(":")[-1][-2] == "%":

        obj.add(lines.split(":")[0])


for items in obj:
    file_out.write(items)
    file_out.write(",")

if obj.__len__() ==0:
    file_out.write("No item is detected")
file_in.close()
file_out.close()