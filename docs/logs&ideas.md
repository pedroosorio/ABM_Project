##Setor externo 
* [x] - Não está sujeito a taxas: Adicionada flag que identifica um produtor como sendo do setor interno ou externo   

##Para organizações   
Produtor de Regras :    
* [ ] - A troco de numerário produz uma regra (máquina) nova.   
* [ ] - A troco de numerário aumenta os níveis de produção de uma regra (máquina).   

##Crédito								
* [x] - Criar tipo 'CreditContract' para guardar dados sobre um contrato de crédito
   * Montante
   * Prazo de Pagamento
   * Juro
   * Montante Vencido
   * Cliente que recebe   
   * Cliente que empresta
   
* [ ] - Criar função que processe os créditos. Faz os pagamentos entre o lender e o borrower. Caso o montante seja vencido elimina o crédito da lista de ambos. Caso o prazeo de pagamento seja ultrapassado ?????

##Produtores
* [x] - Criar lista de créditos para armazenar os vários créditos contraidos por um agente
* [x] - Criar uma variável que permita guardar o valor de investimento ,poupanças e bens de um agente


##Banking ????
Solvência ? Nao emprestar.

Criar tipo 'Bank' que fornece o crédito.
No fim do periodo, percorre se os creditos de contrato e recebe o pagamento com juros do montante.
