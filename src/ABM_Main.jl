using ABM
###################################################################################
#Defines system's initialization file name : System.SystemID.json
#Defines system's output file name : simulation.SystemID.txt
SystemID = "new"; #System Identifier (Simulation ID)
###################################################################################
#Main Simulation Program
println("     ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼")
println("Agent-Based Modelling Simulator");
time = now();
println("Exec @ $time");
println("Running the following test: $SystemID");
println("     ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼ \n")

outputFileName = string("../outputs/simulation.",SystemID,".txt");
systemConfigFileName = string("../configs/System.",SystemID,".json");

S,K,N= SuperSystem(systemConfigFileName);
f = open(outputFileName,"w");

S.CheckSys(f,1,false); #Prints to output file the stores values of each producer STARTING POINT

println("   ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼")
println("  Starting Simulation ... $K Periods");
println("   ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼ \n")

for period = 1:K
  S.NecessaryRulesConsumption(period) #Consumption of Necessary Rules
  S.ProductionAnnouncement(period) #Producers announce what they can produce,
  S.BuyItems(period) #Producers buy what they want/need from other producers
  S.ControllerAction(period)
  S.ProcessCredit(period)
  S.ApplyTaxes(period)
  S.CheckSys(f,period+1,false); #Prints to output file the stores values of each producer
  #period+1 and not period because the minimum array index in Scilab is 1
end

println("  ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼")
println(" Simulation terminated");
println("  ▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼ \n")
S.PlotResults();
S.CheckSys(f,K,true);
close(f)

###################################################################################
# PROCEDURE FOR EACH PERIOD
#1. In the first step, the necessary rules in all producers operate.
#2. In the second step, all producers make offers for production and price of possible rules output.
#3. In the third step, all producers decide what to buy and try to buy what they decided; the controller
# buys the products it commanded, up to the numbers set for the cycle.
#4. In the fourth step, the controller applies taxed to all producers.
#5. In the fifth step, the credit is processed between lenders and borrowers
###################################################################################
