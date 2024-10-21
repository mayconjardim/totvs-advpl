#include "TOTVS.ch"    
#include "Topconn.ch"  
#include "RESTFUL.CH"
#include "protheus.ch"

WSRESTFUL PEDCOM DESCRIPTION "API REST " FORMAT APPLICATION_JSON

WSMETHOD GET ConsultaSimples;
    DESCRIPTION "API utilizada para retornar uma mensagem fixa";
    PATH "/consultar/mensagem/";
    PRODUCES APPLICATION_JSON

END WSRESTFUL

WSMETHOD GET ConsultaPedido WSSERVICE PEDCOM
    Local aDados      := {}
    Local cLinkWorkItem
    Public aResultado := {}
    oResponse         := JsonObject():New()


    //1� Requisi��o para retonar dados necessarios do ePed
    aDados := BuscandoCasoPorEped("2024-09-15", "000746", "ePed026849") //dados que ser�o passados pelo Microsiga -> Data de Vencimento/N� da Nota/ePed
    
    //Retorna o workitem que deve ser atualizado
    cLinkWorkItem := RetornarWorkItem(aDados)

    //dados que ser�o passados pelo Microsiga -> Data de Pagamento/Servi�o?/Internacional?
    oResponse := CriarParametrosIniciaisJson("2024-10-15T18:00:00", .F., .F.)

    EnviarConfirmacaoPagamento(cLinkWorkItem, oResponse)

    oResponse["Resultado: "] := aResultado
    self:SetResponse( EncodeUTF8(oResponse:ToJson()) )
    FreeObj( oResponse )
    oResponse := Nil

Return 



/*/{Protheus.doc} BuscarCasoPorEped
Static Function respons�vel para buscar o eped que tem que ser atualizado.
@type function
@version  1.0
@author MayconJ
@since 10/14/2024
@param cDataVencimento, character, Data de vencimento do pagamento deve ser passado como YYYY/MM/DD
@param cNumeroNota, character, Numero da NF Relacionada ex: (000013346)
@param cNumeroEped, character, Numero do ePed ex: (ePed026849)
@return array, retorna um array contendo o processEntityKey e id do caso encontrato, dados necesssarios pra proxima requisi��o.
/*/
Static Function BuscandoCasoPorEped(cVenc, cNota, cEped)
    Local cServidor       := "https://10.1.43.64/eProcessos/odata/data/"
    Local oRest           := FwRest():New(cServidor)
    Local aHeader         := {}
    Local aCasoEncontrado := {}
    Local oObjPricipal    := Nil
    Local oObjCasos       := Nil
    Local oObjParametros  := Nil
    Local oObjValores     := Nil
    Local cResposta
    Local cParseResposta
    Local iTotal
    Local i
    Local cBuscaVenc
    Local cBuscaNota

    //Preenche o cabe�alho da requisi��o
    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "Authorization: Bearer 791d06b91bc7fe393b6ee148d16b2f61e1ca5454821cd9acd2616c5d2d96ece4")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")
    
    //Define o caminho da requisi��o com o n�mero do EPED
    oRest:setPath("searchByCaseNumber(caseNumber='" + cEped  + "')")

    // Envia a requisi��o e verifica se a resposta foi recebida com sucesso
    if oRest:get(aHeader)
        // Obt�m o resultado da requisi��o
        cResposta := oRest:getResult()

        // Inicializa o objeto para casos
        oObjPricipal   := JsonObject():New()
        oObjCasos      := JsonObject():New()
        oObjParametros := JsonObject():New()
        oObjValores    := JsonObject():New()

        // Faz o parsing da resposta JSON
        cParseResposta := oObjPricipal:fromJson(cResposta)

        // Verifica se a resposta n�o est� vazia
        if empty(cParseResposta)
            oObjCasos := oObjPricipal["value"]
            iTotal := len(oObjCasos)

                for i := 1 to iTotal

                    // Acessa os par�metros do caso
                    oObjParametros := oObjCasos[i]["parameters"]
                    
                    //Pegando valor da data Nascimento
                    oObjValores    := oObjParametros[1]
                    cBuscaVenc     := oObjValores["value"]

                    //Pegando valor da nota
                    oObjValores    := oObjParametros[2]
                    cBuscaNota     := oObjValores["value"]
                    
                  //Verificando data vencimento e Numero da nota batem com oque foi fornecido
                  If At(cVenc, SubStr(cBuscaVenc, 1, 10)) > 0 && At(cNota, SubStr(cBuscaNota, 1, 10)) > 0
                    AAdd(aCasoEncontrado, oObjCasos[i]["@processEntityKey"])
                    AAdd(aCasoEncontrado, LTrim(Str(oObjCasos[i]["id"])))
                  EndIf
                   
                next
        endif

    endif
    
Return (aCasoEncontrado)

/*/{Protheus.doc} RetornarWorkItem
Fun��o que retorna o Link do WorkItem que deve ser Atualizado
@type function
@version  1.0
@author MayconJ
@since 10/15/2024
@param aCasoEncontrado, array, Array com cProcessKey e cCaseId que s�o retornados no BuscandoCasoPorEped
@return variant, retorna o Link do Workitem
/*/
Static Function RetornarWorkItem(aCasoEncontrado)
    Local cServidor      := "https://10.1.43.64/eProcessos/odata/data/"
    Local oRest          := FwRest():New(cServidor)
    Local aHeader        := {}
    Local cResposta
    Local cParseResposta
    Local oObjPricipal   := Nil
    Local oObjValores      := Nil
    Local cProcessKey
    Local cCaseId
    Local iTotal
    Local I
    Local cEnderecoWorkItem

    //Preenche o cabe�alho da requisi��o
    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "Authorization: Bearer 791d06b91bc7fe393b6ee148d16b2f61e1ca5454821cd9acd2616c5d2d96ece4")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")

    //Atribui os valores de chave e ID do caso do array passado como argumento
    cProcessKey := aCasoEncontrado[1] 
    cCaseId     := aCasoEncontrado[2]
    
    //Define o caminho da requisi��o para obter work items do caso espec�fico
    oRest:setPath("processes(" + cProcessKey + ")/cases(" + cCaseId + ")/workitems")

    //Envia a requisi��o e verifica se a resposta foi recebida com sucesso
    if oRest:get(aHeader)

        //Cria um novo objeto JSON para a resposta
        cResposta         := oRest:getResult()

         //Inicializa os objetos
        oObjPricipal := JsonObject():new()
        oObjValores := JsonObject():new()

        //Faz o parsing da resposta JSON
        cParseResposta := oObjPricipal:fromJson(cResposta)

        //Verifica se a resposta n�o est� vazia
        if empty(cParseResposta)

            //Acessa a lista de work items
            oObjValores := oObjPricipal["value"]

            //Obt�m a quantidade total de work items
            iTotal := len(oObjValores)

            //Itera sobre cada work item encontrado
            for I := 1 to iTotal

                    //Verifica se o nome da tarefa cont�m "Confirmar Pagamento"
                    If At("Confirmar Pagamento", SubStr(oObjValores[i]["taskDisplayName"], 1, 20)) > 0 
                        cEnderecoWorkItem:= oObjValores[i]["@odata.id"]
                    EndIf    
            next

        endif

    endif
  
Return (cEnderecoWorkItem)

/*/{Protheus.doc} CriarParametrosIniciaisJson
Monta o Json que ser� enviado ao eprocessos
@type function
@version  1.0
@author MayconJ
@since 10/15/2024
@param cDtPagamento, character, Data de Pagamento
@param lServico, logical, Emitir Nota de Servi�o?
@param lInternacional, logical, Pagamento Internacional?
@return variant, retorna o Json para ser enviado ao eprocessos
/*/
Static Function CriarParametrosIniciaisJson(cDtPagamento, lServico, lInternacional)

    Local oJson := JsonObject():New()

    // Criando o array startParameters como um array vazio
    oJson['startParameters'] := {}

    // Adicionando manualmente um objeto dentro do startParameters
    Local oParam := JsonObject():New()
    oParam['xpath'] := "Pagamento.SuspenderCobranca"
    oParam['value'] := .F.
    aAdd(oJson['startParameters'], oParam)
    
    //MotivoSuspencao
    oParam := JsonObject():New()
    oParam['xpath'] := "Pagamento.MotivoSuspencao"
    oParam['value'] := "2f46f2fe-8d42-46fe-87e4-6db147d09d34"
    aAdd(oJson['startParameters'], oParam)

    //DtSuspensaoCobranca
    oParam := JsonObject():New()
    oParam['xpath'] := "Pagamento.DtSuspensaoCobranca"
    oParam['value'] := cDtPagamento
    aAdd(oJson['startParameters'], oParam)

    //DtEstimadaPausa
    oParam := JsonObject():New()
    oParam['xpath'] := "Pagamento.DtEstimadaPausa"
    oParam['value'] := cDtPagamento
    aAdd(oJson['startParameters'], oParam)

    //DatadePagamento
    oParam := JsonObject():New()
    oParam['xpath'] := "Pagamento.DatadePagamento"
    oParam['value'] := cDtPagamento
    aAdd(oJson['startParameters'], oParam)

    //PagamentoConfirmado
    oParam := JsonObject():New()
    oParam['xpath'] := "Pagamento.PagamentoConfirmado"
    oParam['value'] := .T.
    aAdd(oJson['startParameters'], oParam)

    //Servico
    oParam := JsonObject():New()
    oParam['xpath'] := "Pagamento.Servico"
    oParam['value'] := lServico
    aAdd(oJson['startParameters'], oParam)


    //PagamentoInternacional
    oParam := JsonObject():New()
    oParam['xpath'] := "Pagamento.PagamentoInternacional"
    oParam['value'] := lInternacional
    aAdd(oJson['startParameters'], oParam)
    

Return (oJson)

/*/{Protheus.doc} EnviarConfirmacaoPagamento
Envia a confirma��o de pagamento ao eprocessos
@type function
@version 1.0
@author MayconJ
@since 10/15/2024
@param cPath, character, Link do workitem retornado na fun��o RetornarWorkItem
@param oResponse, object, Json que ser� enviado gerado na fun��o CriarParametrosIniciaisJson
@return variant, retorna a resposta do servidor.
/*/
Static Function EnviarConfirmacaoPagamento(cPath, oResponse)
    Local cServidor      := cPath
    Local oRest          := FwRest():New(cServidor)
    Local aHeader        := {}

    //Preenche o cabe�alho da requisi��o
    AAdd(aHeader, "Content-Type: application/json; charset=UTF-8")
    AAdd(aHeader, "Accept: application/json")
    AAdd(aHeader, "Authorization: Bearer 791d06b91bc7fe393b6ee148d16b2f61e1ca5454821cd9acd2616c5d2d96ece4")
    AAdd(aHeader, "User-Agent: Chrome/65.0 (compatible; Protheus " + GetBuild() + ")")

    // Define o caminho da requisi��o para obter work items do caso espec�fico
    oRest:setPath("/next")

    orest:SetPostParams(oResponse:toJson());

    if oRest:post(aHeader)
        cResposta         := oRest:getResult()
       AAdd(aResultado, cResposta)
    endif

    FreeObj(oRest)

Return 




