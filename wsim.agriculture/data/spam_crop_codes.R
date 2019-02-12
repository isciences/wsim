spam_crops <- utils::read.table(sep='\t', header=TRUE, stringsAsFactors=FALSE, text='
spam_id	spam_name	food
1	wheat	TRUE
2	rice	TRUE
3	maize	TRUE
4	barley	TRUE
5	pearl millet	TRUE
6	small millet	TRUE
7	sorghum	TRUE
8	other cereals	TRUE
9	potato	TRUE
10	sweet potato	TRUE
11	yams	TRUE
12	cassava	TRUE
13	other roots	TRUE
14	bean	TRUE
15	chickpea	TRUE
16	cowpea	TRUE
17	pigeonpea	TRUE
18	lentil	TRUE
19	other pulses	TRUE
20	soybean	TRUE
21	groundnut	TRUE
22	coconut	TRUE
37	banana	TRUE
38	plantain	TRUE
39	tropical fruit	TRUE
40	temperate fruit	TRUE
41	vegetables	TRUE
23	oilpalm	FALSE
24	sunflower	FALSE
25	rapeseed	FALSE
26	sesameseed	FALSE
27	other oil crops	FALSE
28	sugarcane	FALSE
29	sugarbeet	FALSE
30	cotton	FALSE
31	other fibre crops	FALSE
32	arabica coffee	FALSE
33	robusta coffee	FALSE
34	cocoa	FALSE
35	tea	FALSE
36	tobacco	FALSE
42	rest of crops	FALSE
')

# mirca_id	spam_id
# 1	1
# 2	3
# 3	2
# 4	4
# 5	RYE = OTHER CEREALS (8) ?
# 6	5+6
# 7	7
# 8	20
# 9	24
# 10	9
# 11	12
# 12	28
# 13	29
# 14	23
# 15	25
# 16	21
# 17	18+19
# 18	"citrus"	1
# 19	"date palm"	1
# 20	"grapes / vine"	1
# 21	30
# 22	34
# 23	32+33
# 24	"others perennial"	1
# 25	"fodder grasses"	1
# 26	"others annual"	3
# 
