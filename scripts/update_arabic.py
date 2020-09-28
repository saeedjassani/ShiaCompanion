# -*- coding: UTF-8 -*-
# Script to create New Quran data from Tanzil.net
# Using help from AHAD json file

import json
import urllib2
import io

import sys
reload(sys)
sys.setdefaultencoding('utf-8')

# Opens quran.json file and store it in "data" object as JSON object
with open('new_quran.json') as f:
    data = json.load(f)

with open('quran-uthmani.txt') as f:
    arabic = f.readlines()
with open('en.shakir.txt') as f:
    english = f.readlines()
with open('en.transliteration.txt') as f:
    transliteration = f.readlines()

arabic = [x.strip() for x in arabic] 
english = [x.strip() for x in english] 
transliteration = [x.strip() for x in transliteration] 


cum = 0

# Iterates data JSON array for every existing surah
for surah in data:

    ayahCount = surah["ayahCount"]
    newAyahs = []
    dataString = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ\nIn the name of Allah, the Beneficent, the Merciful.\n"
    for i in range(1, ayahCount + 1):
        # newAyahs.append(urdu[cum])
        dataString += arabic[cum] + " ({}) \n".format(i)
        # dataString += transliteration[cum] + "\n"
        dataString += english[cum].split("|")[2] + "\n"
        
        cum += 1
    # print(cum)
    itemJson = {}
    itemJson['code'] = '012'
    itemJson['data'] = dataString.strip()
    itemJson['title'] = str(surah['number']) + ": " + surah['english'] + " " + surah['arabic'] 
    
    with io.open('quran_zikr/A' + str(4 + surah['number']), 'w', encoding='utf-8') as outfile:
        outfile.write(unicode(json.dumps(itemJson, ensure_ascii=False, indent=4)))

    # surah['urdu'] = newAyahs

