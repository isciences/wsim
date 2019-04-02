wsim_crops <- utils::read.table(sep='\t', header=TRUE, stringsAsFactors=FALSE, 
                          colClasses=c("integer", "character","logical"), text='
wsim_id	wsim_name	food
1	wheat	TRUE
2	rice	TRUE
3	maize	TRUE
4	barley	TRUE
5	millet	TRUE
6	sorghum	TRUE
7	soybeans	TRUE
8	sunflower	FALSE
9	potatoes	TRUE
10	cassava	TRUE
11	sugarcane	FALSE
12	sugarbeets	FALSE
13	oilpalm	FALSE
14	rapeseed	FALSE
15	groundnuts	TRUE
16	pulses	TRUE
17	cotton	FALSE
18	cocoa	FALSE
19	coffee	FALSE
')
