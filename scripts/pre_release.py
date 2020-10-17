# Script to update Zikr from Airtable

import io
# U_ID,Title,Data,Code,Audio URL,Last Modified By,Created By,Last Modified Time
import sys
import json
reload(sys)
sys.setdefaultencoding('utf-8')

with open('all_zikr.json') as f:
    data = json.load(f)


# with open('zikr.csv') as f:
#     reader = csv.reader(f)
#     data = list(reader)

# print(data['A1'])
uidTitle = {}
for x in data:
    
    if data[x]['Data'] != None or '~' in x or '|' in x:
        if '|' in x and data[x.split('|')[1]]['Data'] == None:
            continue
        uidTitle[x] = data[x]['Title']

for uid in uidTitle:
    if '~' in uid or '|' in uid: continue
    zikr = {}
    zikr['title'] = data[uid]['Title']
    zikr['code'] = data[uid]['Code']
    zikr['data'] = data[uid]['Data']
    with io.open('zikr/' + uid, 'w', encoding='utf-8') as outfile:
        outfile.write(unicode(json.dumps(zikr, ensure_ascii=False, indent=4)))

with io.open('zikr.json', 'w', encoding='utf-8') as outfile:
	outfile.write(unicode(json.dumps(uidTitle, ensure_ascii=False, indent=4)))