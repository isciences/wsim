wsim_crops <- utils::read.table(sep='\t', header=TRUE, stringsAsFactors=FALSE, 
                          colClasses=c("integer", "character","logical","logical"), text='
wsim_id	wsim_name	food	implemented
1	wheat	TRUE	TRUE
2	rice	TRUE	TRUE
3	maize	TRUE	TRUE
4	barley	TRUE	FALSE
5	millet	TRUE	FALSE
6	sorghum	TRUE	FALSE
7	soybeans	TRUE	TRUE
8	sunflower	FALSE	FALSE
9	potatoes	TRUE	TRUE
10	cassava	TRUE	FALSE
11	sugarcane	FALSE	FALSE
12	sugarbeets	FALSE	FALSE
13	oilpalm	FALSE	FALSE
14	rapeseed	FALSE	FALSE
15	groundnuts	TRUE	FALSE
16	pulses	TRUE	FALSE
17	cotton	FALSE	FALSE
18	cocoa	FALSE	FALSE
19	coffee	FALSE	FALSE
')
