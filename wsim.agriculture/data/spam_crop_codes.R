spam_crops <- utils::read.table(sep='\t', header=TRUE, stringsAsFactors=FALSE,
                                colClasses=c("integer", "character", "character", "integer", "logical"),
                                text='
spam_id	spam_name	spam_abbrev	wsim_id	food
1	wheat	whea	1	TRUE
2	rice	rice	2	TRUE
3	maize	maiz	3	TRUE
4	barley	barl	4	TRUE
5	pearl millet	pmil	5	TRUE
6	small millet	smil	5	TRUE
7	sorghum	sorg	6	TRUE
8	other cereals	ocer	NA	TRUE
9	potato	pota	9	TRUE
10	sweet potato	swpo	NA	TRUE
11	yams	yams	NA	TRUE
12	cassava	cass	10	TRUE
13	other roots	orts	NA	TRUE
14	bean	bean	16	TRUE
15	chickpea	chic	16	TRUE
16	cowpea	cowp	16	TRUE
17	pigeonpea	pige	16	TRUE
18	lentil	lent	16	TRUE
19	other pulses	opul	16	TRUE
20	soybean	soyb	7	TRUE
21	groundnut	grou	15	TRUE
22	coconut	cnut	NA	TRUE
37	banana	bana	NA	TRUE
38	plantain	plnt	NA	TRUE
39	tropical fruit	trof	NA	TRUE
40	temperate fruit	temf	NA	TRUE
41	vegetables	vege	NA	TRUE
23	oilpalm	oilp	13	FALSE
24	sunflower	sunf	8	FALSE
25	rapeseed	rape	14	FALSE
26	sesameseed	sesa	NA	FALSE
27	other oil crops	ooil	NA	FALSE
28	sugarcane	sugc	11	FALSE
29	sugarbeet	sugb	12	FALSE
30	cotton	cott	17	FALSE
31	other fibre crops	ofib	NA	FALSE
32	arabica coffee	acof	19	FALSE
33	robusta coffee	rcof	19	FALSE
34	cocoa	coco	18	FALSE
35	tea	teas	NA	FALSE
36	tobacco	toba	NA	FALSE
42	rest of crops	rest	NA	FALSE
')
