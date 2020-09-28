# -*- coding: UTF-8 -*-
import os,glob,json,io,csv
import sys
reload(sys)
sys.setdefaultencoding('utf-8')
folder_path = '.'
abc = csv.writer(open("test.csv", "wb+"))
abc.writerow(["u_id", "title", "code", "data"])
for filename in glob.glob(os.path.join(folder_path, '*')):
    filename = filename.replace('./', '')
    if '.' in filename: continue
    with io.open(filename, 'r', encoding='utf-8') as f:
        print(f)
        x = json.load(f)
        x['U_ID'] = filename
        abc.writerow([x["U_ID"],
                    x["title"],
                    x["code"],
                    x["data"]
                    ])

