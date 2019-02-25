spam_crops <- utils::read.table(sep='\t', header=TRUE, stringsAsFactors=FALSE,
                                colClasses=c("integer", "character", "integer", "logical"),
                                text='
spam_id	spam_name	wsim_id	food
1	wheat	1	TRUE
2	rice	2	TRUE
3	maize	3	TRUE
4	barley	4	TRUE
5	pearl millet	5	TRUE
6	small millet	5	TRUE
7	sorghum	6	TRUE
8	other cereals	NA	TRUE
9	potato	9	TRUE
10	sweet potato	NA	TRUE
11	yams	NA	TRUE
12	cassava	10	TRUE
13	other roots	NA	TRUE
14	bean	16	TRUE
15	chickpea	16	TRUE
16	cowpea	16	TRUE
17	pigeonpea	16	TRUE
18	lentil	16	TRUE
19	other pulses	16	TRUE
20	soybean	7	TRUE
21	groundnut	15	TRUE
22	coconut	NA	TRUE
37	banana	NA	TRUE
38	plantain	NA	TRUE
39	tropical fruit	NA	TRUE
40	temperate fruit	NA	TRUE
41	vegetables	NA	TRUE
23	oilpalm	13	FALSE
24	sunflower	8	FALSE
25	rapeseed	14	FALSE
26	sesameseed	NA	FALSE
27	other oil crops	NA	FALSE
28	sugarcane	11	FALSE
29	sugarbeet	12	FALSE
30	cotton	17	FALSE
31	other fibre crops	NA	FALSE
32	arabica coffee	19	FALSE
33	robusta coffee	19	FALSE
34	cocoa	18	FALSE
35	tea	NA	FALSE
36	tobacco	NA	FALSE
42	rest of crops	NA	FALSE
')
