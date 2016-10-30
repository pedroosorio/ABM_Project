//2345678901234567890123456789012345678901234567890123456789
/////////////////////////
//
//
// Visualizer for ABM
//
// Version:2
//
/////////////////////////


// Requires to write the name of ABM's
// output file


clear
user = getenv("USER");
if(user=="pedro") chdir(getenv("HOME")+"/git/ABM_Project/tools")
// Get file info
SystemID = "TestA1"
inputFileName = "../outputs/simulation."+SystemID+".txt"
[f,e]=mopen(inputFileName,"rt")
info=mgetl(f,-1)
mclose(f)

// Get simulation parameters

params=info(1:5)
disp(params,'Simulation params:')

execstr(params)

//Get shorter names

K=NumberOfPeriods
K0=K+1
N=NumberOfProducers
NC=N+1

//Set empty matrices for data

inputStore_A=zeros(N,K0)
inputStore_B=zeros(N,K0)
inputStore_E=zeros(N,K0)
inputStore_F=zeros(N,K0)

offers=zeros(N,K)

buy_A=zeros(NC,K)
buy_B=zeros(NC,K)
buy_D=zeros(NC,K)
buy_E=zeros(NC,K)
buy_F=zeros(NC,K)

sales=zeros(N,K)

totalSales=zeros(1,K)

taxes=zeros(N,K)
totalTaxes=zeros(1,K)

numeraires=zeros(N,K)
totalNumeraires=zeros(1,K)

//Get simulated data

data=info(6:$)

//disp(data)

execstr(data)   //Because the data comes from the simulator
                //as Scilab commands this sets the values
                //of offers, buy_X, taxes and numeraires
                

//Calculate aggregates from simulated data

sales(1,:)=sum(buy_A,'r')
sales(2,:)=sum(buy_B,'r')
sales(3,:)=sum(buy_D,'r')
sales(4,:)=sum(buy_E,'r')
sales(5,:)=sum(buy_F,'r')

prices=[0.625 3.4166666666666667 16.75 1.0 2.625]

//Corresponding spendings and sales proceeds by agents 
//at the steady-state
//
//spend_1=2*1+4*2.625=12.5
//spend_2=92*1+4*2.625=102.5
//spend_3=20*0.625+30*(102.5/30)+42*1+4*2.625=167.5
//spend_4=4*2.625=10.5
//spend_5=42*1=42
//proceeds=prices'.*salesSS=
//    12.5   
//    102.5  
//    167.5  
//    178.   
//    42.   

totalSales=prices*sales

totalTaxes=sum(taxes,'r')

totalCPurchases=prices(3)*sales(3,:)

totalNumeraires=sum(numeraires,'r')

//Plot data against time

//Canonical plotting requires to include values of variables
//at instant 0. In general, these should be communicated by 
//the simulator. This is the case for the inputStore_X, but //not the case for the other variables.
//In this case, we will be assuming that all 
//simulations depart from the "steady-state" defined in the 
//"system", therefore at instant 0 variable values are in 
//the steady-sate.

offers_0=[20.    30.    10.    178.    16.]'

buy_A_0=[0.    0.   20.    0.    0.    0.]'
buy_B_0=[0.    0.   30.    0.    0.    0.]'
buy_D_0=[0.    0.    0.    0.    0.   10.]'
buy_E_0=[2.   92.   42.    0.   42.    0.]'
buy_F_0=[4.    4.    4.    4.    0.    0.]'

sales_0=[20.    30.    10.    178.    16.]'

totalSales_0=502.5

taxes_0=[0.    0.    0.    167.5    0.]'

totalTaxes_0=167.5

totalCPurchases_0=167.5

numeraires_0=[300.    300.    300.    300.    300.]'


//Now we tweak variables to include the instant 0.

function What=shift(upTo,What,Insert)
    
for k=upTo:-1:2
    What(:,k)=What(:,k-1)
end
What(:,1)=Insert    

endfunction

offers=shift(K0,offers,offers_0)

buy_A=shift(K0,buy_A,buy_A_0)

buy_B=shift(K0,buy_B,buy_B_0)

buy_D=shift(K0,buy_D,buy_D_0)

buy_E=shift(K0,buy_E,buy_E_0)

buy_E=shift(K0,buy_E,buy_E_0)

sales=shift(K0,sales,sales_0)

totalSales=shift(K0,totalSales,totalSales_0)

taxes=shift(K0,taxes,taxes_0)

totalTaxes=shift(K0,totalTaxes,totalTaxes_0)

totalCPurchases=shift(K0,totalCPurchases,totalCPurchases_0)

numeraires=shift(K0,numeraires,numeraires_0)

// Next we need to define the plot
// legends to use

yP='Units of product'
yN='Units of numeraire'
agentsLegend=['A1','A2','A3','A4','A5','C']
aggregatesLegend=['Total sales','Total taxes','Total C purchases']


//Now we are ready to plot

function plotSystem(VariablesName,Data,YLegend,Legend,Window)

scf(Window)
clf(Window)
grey=addcolor(name2rgb('grey')/255);//To use in grids
drawlater

[I,K0]=size(Data)
K=K0-1
time=0:1:K
timeLabels=string(time)
max_x=K

plot(time',Data')
g=gca()
g.title.text=VariablesName;
g.title.font_size=6;
g.x_label.text='Discrete time';
g.x_label.font_size=4;
g.y_label.text=YLegend;
g.y_label.font_size=4;
g.x_ticks=tlist(["ticks" "locations", "labels"], time', timeLabels')
g.sub_ticks=[0,1]
x_ticks.font_size=%pi
y_ticks.font_size=50
g.grid=[grey grey]//Grid in gray
if  max(Data)==max(g.y_ticks.locations) then 
    max_y=1.02*max(Data)
else
    max_y=max(g.y_ticks.locations)
end
g.tight_limits='on'
g.data_bounds = [0,-1;max_x,max_y];
g.children.children.thickness=3
g.children.children.mark_mode='on'
g.children.children.mark_style = 11
g.children.children.mark_size_unit = "point"
g.children.children.mark_size = 5
g.children.children.mark_foreground = 1
g.children.children.mark_background = 1
legend(Legend,-4)
drawnow

endfunction


plotSystem('Aggregates',[totalSales;totalTaxes;totalCPurchases],yN,aggregatesLegend,0)
plotSystem('Numeraires',numeraires,yN,agentsLegend,1)
plotSystem('Taxes',taxes,yN,agentsLegend,2)
plotSystem('Sales',sales,yP,agentsLegend,3)
plotSystem('Offers',offers,yP,agentsLegend,4)







