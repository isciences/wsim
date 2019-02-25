mirca_crops <- utils::read.table(sep='\t', header=TRUE, stringsAsFactors=FALSE,
	        colClasses=c("integer", "character", "integer", "integer"),
	        text='
mirca_id	mirca_name	wsim_id	mirca_subcrops
1	"wheat"	1	2
2	"maize"	3	2
3	"rice"	2	5
4	"barley"	4	2
5	"rye"	NA	2
6	"millet"	5	1
7	"sorghum"	6	2
8	"soybeans"	7	1
9	"sunflower"	8	1
10	"potatoes"	9	2
11	"cassava"	10	1
12	"sugar cane"	11	1
13	"sugar beet"	12	1
14	"oil palm"	13	1
15	"rape seed / canola"	14	1
16	"groundnuts / peanuts"	15	1
17	"pulses"	16	1
18	"citrus"	NA	1
19	"date palm"	NA	1
20	"grapes / vine"	NA	1
21	"cotton"	17	1
22	"cocoa"	18	1
23	"coffee"	19	1
24	"others perennial"	NA	1
25	"fodder grasses"	NA	1
26	"others annual"	NA	3
')
