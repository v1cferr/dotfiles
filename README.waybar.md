
# **Guia Exaustivo para Personalização Minimalista do Waybar no Hyprland**

## **Parte I: Fundamentos do Design Minimalista do Waybar no Hyprland**

Esta secção estabelece os princípios fundamentais, transitando da teoria de design abstrata para a implementação concreta nos ficheiros de configuração primários do Waybar.

### **Deconstruindo a Estética Minimalista na Personalização de Desktops (Ricing)**

A personalização de ambientes de trabalho Linux, frequentemente designada por "ricing", é uma prática que visa otimizar tanto a funcionalidade como a estética. Dentro deste domínio, a estética minimalista tornou-se proeminente, particularmente em comunidades como r/unixporn.1 O objetivo primordial do minimalismo neste contexto não é a mera remoção de elementos, mas a obtenção de uma elevada relação sinal-ruído, onde cada componente visual serve um propósito claro e intencional, eliminando a desordem supérflua.  
A análise de configurações minimalistas populares revela um conjunto de princípios fundamentais que orientam as escolhas de design 2:

* **Hierarquia da Informação:** Uma técnica central é a diferenciação entre informação primária e secundária. A informação primária, como a hora atual ou o espaço de trabalho ativo, está sempre visível. A informação secundária, como a data completa, um calendário mensal ou detalhes da rede, é revelada apenas através de interação, como passar o cursor sobre um módulo (hover) ou clicar. Esta abordagem em camadas reduz drasticamente a carga cognitiva da interface principal.  
* **Espaço Negativo:** O uso estratégico de espaço vazio, através de margens e preenchimento (padding), é crucial. O espaço negativo não é espaço desperdiçado; é um elemento de design ativo que guia o foco do utilizador, cria uma sensação de calma e ordem, e melhora a legibilidade ao separar visualmente os diferentes módulos de informação.  
* **Clareza Tipográfica:** A tipografia transcende a sua função de apresentar texto para se tornar um elemento de design central. A escolha de uma fonte limpa e legível, frequentemente monoespaçada como JetBrains Mono Nerd Font ou Fira Code, contribui para uma estética coesa e funcional.7 A consistência no tamanho e peso da fonte é vital para manter a harmonia visual.  
* **Teoria de Cor Coesiva:** As configurações minimalistas evitam paletas de cores complexas ou dissonantes. Em vez disso, utilizam um número limitado de cores que funcionam em harmonia. Uma prática comum e eficaz é derivar a paleta de cores do papel de parede do ambiente de trabalho, utilizando ferramentas como o Pywal. Esta abordagem garante que a barra de estado se integra perfeitamente com o resto do ambiente, criando uma experiência visual unificada e agradável.2

### **Arquitetando a Barra: Configuração Global (config.jsonc)**

A base de qualquer configuração do Waybar reside no seu ficheiro principal, config.jsonc, localizado em \~/.config/waybar/.9 Este ficheiro, que utiliza o formato JSON with Comments (JSONC), define a presença física, o comportamento e a disposição dos módulos na barra.10 Para uma estética minimalista, certas configurações globais são de importância crítica.

* layer: Esta propriedade determina o empilhamento da barra em relação às janelas das aplicações. O valor "top" garante que a barra está sempre visível e acessível por cima das janelas, o que é preferível para a maioria dos fluxos de trabalho. O valor "bottom" coloca a barra atrás das janelas, o que pode criar uma sensação mais integrada, mas pode ser menos prático.9  
* position: Define a localização da barra no ecrã. Embora "top" e "bottom" sejam as escolhas convencionais, uma orientação vertical como "right" pode ser uma estratégia minimalista surpreendentemente eficaz. Ao mover a barra para o lado, liberta-se espaço vertical, que é frequentemente mais valioso em ecrãs panorâmicos, e a barra torna-se menos intrusiva no campo de visão principal.2 A rotação do conteúdo dos módulos pode ser necessária para esta orientação.10  
* height: Para um perfil fino e discreto, é comum definir uma altura fixa e pequena, como 30 pixels. Se a propriedade for omitida, o Waybar calculará a altura dinamicamente com base no conteúdo e no preenchimento, o que também pode ser desejável para se adaptar ao tamanho da fonte.10  
* margin: Em vez de ter uma barra que ocupa toda a largura do ecrã, a utilização de margens pode criar um efeito de "barra flutuante". A propriedade margin aceita valores no formato CSS (por exemplo, "5 10" para 5px de margem superior/inferior e 10px de margem esquerda/direita), permitindo que a barra se destaque do limite do ecrã, uma tendência popular no design moderno.10  
* modules-left, modules-center, modules-right: A disposição dos módulos é fundamental para o equilíbrio visual. Uma abordagem minimalista pode concentrar todos os módulos num único lado para maximizar o espaço negativo, ou distribuí-los simetricamente para criar uma sensação de ordem e estabilidade. A análise de diferentes configurações mostra que não há uma única "melhor" disposição; a escolha depende do fluxo de trabalho e da preferência estética do utilizador.9

### **A Arte da Subtileza: Estilização com Folhas de Estilo em Cascata (style.css)**

Enquanto o config.jsonc define a estrutura, o ficheiro style.css (localizado no mesmo diretório) define a identidade visual. O Waybar utiliza um subconjunto de CSS para estilizar a barra e os seus módulos, permitindo um controlo granular sobre a aparência.10 A análise de ficheiros  
style.css da comunidade revela técnicas recorrentes para alcançar uma estética minimalista.7

* **Reset Universal (\*)**: É uma prática comum começar o style.css com um seletor universal (\*) para estabelecer uma base limpa e consistente. Definir border: none; e border-radius: 0; remove todas as bordas e cantos arredondados, criando uma aparência nítida e plana que serve como um excelente ponto de partida para um design minimalista.7  
* **Transparência (window\#waybar)**: Para integrar a barra com o papel de parede, a utilização de cores com um canal alfa é essencial. A propriedade background-color: rgba(0, 0, 0, 0.5); cria um fundo preto semitransparente, resultando num efeito de "vidro fosco" ou "glassmorphism" que é visualmente leve e moderno.7  
* **Espaçamento (padding, margin)**: O controlo preciso do espaçamento é vital. Um preenchimento horizontal mínimo nos módulos (por exemplo, padding: 0 5px;) mantém-nos compactos e finos. As margens são usadas para criar separação deliberada entre os módulos ou grupos de módulos, evitando uma aparência apinhada.7  
* **Bordas e Raios (border-radius)**: Embora um reset global para 0 seja uma abordagem, o uso seletivo de border-radius pode criar "pílulas" ou "ilhas" de módulos com cantos arredondados. Uma técnica avançada consiste em aplicar border-radius apenas aos cantos externos de um grupo de módulos, fazendo com que pareçam uma única unidade coesa.11  
* **Transições (transition)**: Para uma experiência de utilizador polida, as transições CSS são indispensáveis. A propriedade transition: background-color 0.3s ease; garante que as mudanças de estado, como ao passar o cursor sobre um botão, ocorram de forma suave e gradual, em vez de abrupta, o que contribui significativamente para a sensação de qualidade da interface.7

A combinação destas técnicas permite a criação de diversos estilos minimalistas. A tabela seguinte compara três estéticas populares, detalhando as propriedades CSS chave para as alcançar.

| Estética | Estilo window\#waybar | Estilo do Módulo (\#module) | Estratégia de Espaçamento | Princípio Chave |
| :---- | :---- | :---- | :---- | :---- |
| **"Vidro Flutuante"** | background: rgba(20, 20, 20, 0.6); border-radius: 15px; | background: transparent; | margin: 10px; padding: 0 8px; | Moderno, destacado, integrado com o papel de parede. |
| **"Nítido e Plano"** | background: \#282828; border-radius: 0; | background: transparent; | margin: 0; padding: 0 10px; | Utilitário, inspirado em terminais, linhas retas. |
| **"Baseado em Pílulas"** | background: transparent; | background: \#3c3836; border-radius: 10px; | margin: 5px 3px; padding: 0 12px; | Modular, agrupamento visual distinto de cada módulo. |

Esta abordagem estruturada à estilização demonstra que o minimalismo no Waybar não é sobre a ausência de design, mas sobre um design deliberado e contido, onde cada escolha de configuração e estilo contribui para um todo coeso e funcional. Uma observação fundamental é que as configurações minimalistas mais eficazes não se limitam a remover informação; elas estruturam-na em camadas. A barra em si apresenta dados de baixa densidade e acesso rápido, enquanto os detalhes de alta densidade são relegados para uma camada secundária, acessível através de interações como hover (com tooltip-format) ou cliques alternativos (com format-alt).12 Esta filosofia transforma o objetivo de "menos informação" para "apresentação de informação mais inteligente".

## **Parte II: Dominando Módulos Essenciais do Waybar para uma Interface Minimalista**

Esta secção aprofunda a configuração de módulos centrais, aplicando consistentemente os princípios minimalistas estabelecidos na Parte I para criar uma barra de estado que é simultaneamente informativa e visualmente limpa.

### **Informação do Sistema num Relance**

A função primária de uma barra de estado é fornecer informações cruciais do sistema de forma rápida e eficiente. A chave para uma implementação minimalista é apresentar apenas o essencial, utilizando ícones e mudanças de cor para transmitir o estado, e relegando os detalhes para interações secundárias.

#### **Relógio (clock)**

O módulo de relógio é um elemento fundamental. A sua configuração pode variar desde uma simples exibição da hora até um complexo widget de calendário.

* **Validação da Configuração:** As páginas de manual confirmam um conjunto robusto de opções, incluindo interval, format, timezone, locale, tooltip-format, e format-alt.12 O  
  format utiliza a sintaxe da biblioteca de datas strftime, permitindo uma personalização detalhada.14  
* **Estratégia Minimalista:** A abordagem mais eficaz é aplicar o princípio da hierarquia da informação.  
  1. Utilizar um format simples para a exibição principal, mostrando apenas as horas e os minutos: "format": "{:%H:%M} ". O ícone (neste caso, ) fornece contexto visual imediato.  
  2. Mover informações mais detalhadas para o format-alt, que pode ser alternado com um clique. Por exemplo: "format-alt": "{:%A, %d de %B de %Y}".12  
  3. Utilizar o tooltip-format para exibir um calendário interativo ao passar o cursor sobre o módulo: "tooltip-format": "\<tt\>\<small\>{calendar}\</small\>\</tt\>". Esta configuração mantém a barra principal limpa, mas oferece funcionalidade completa sob demanda.12

#### **Áudio (pulseaudio)**

O controlo de volume é outra funcionalidade essencial. O objetivo é fornecer feedback visual claro sobre o estado do áudio (volume, dispositivo de saída, estado de mudo) sem sobrecarregar a barra.

* **Validação da Configuração:** A documentação detalha opções como format, format-muted, format-bluetooth, format-icons, e on-click.16 A capacidade de definir ícones diferentes com base no nome da porta (por exemplo,  
  headphone, speaker) e no estado de mudo é particularmente poderosa.16  
* **Estratégia Minimalista:** A ênfase deve ser colocada em ícones em vez de texto.  
  1. Definir o formato principal para mostrar apenas um ícone: "format": "{icon}".  
  2. Configurar format-icons para mapear diferentes dispositivos e níveis de volume para ícones específicos. Por exemplo: "format-icons": { "headphone": "", "handsfree": "", "speaker": "", "default": \["", "", ""\] }. A última entrada (default) pode ser um array que muda com o nível de volume.  
  3. Utilizar format-muted para um feedback inequívoco quando o som está desativado: "format-muted": " {volume}%". O ícone de mudo é instantaneamente reconhecível.  
  4. A percentagem de volume pode ser movida para o tooltip ("tooltip-format": "Volume: {volume}%") ou exibida apenas no estado mudo, reduzindo a desordem visual durante o uso normal. A funcionalidade de scroll para alterar o volume permanece ativa, tornando a interação rápida e intuitiva.

#### **Temperatura (temperature)**

Monitorizar as temperaturas dos componentes é importante para os power users, mas não precisa de ser uma distração constante.

* **Validação da Configuração:** As opções incluem thermal-zone, hwmon-path, critical-threshold, format, e format-critical.13 A capacidade de especificar um  
  hwmon-path diretamente é útil para sistemas onde as zonas térmicas padrão não são fiáveis. A opção hwmon-path também pode aceitar um array de strings, permitindo configurações de fallback para diferentes máquinas.13  
* **Estratégia Minimalista:** A informação deve ser passiva, chamando a atenção apenas quando necessário.  
  1. Exibir apenas a temperatura da CPU com um ícone: "format": "{temperatureC}°C ".  
  2. Definir um critical-threshold (por exemplo, 80 graus Celsius) para indicar uma temperatura perigosa.13  
  3. Utilizar estilização baseada no estado em style.css para alterar a cor do módulo quando este atinge o limiar crítico. Por exemplo: \#temperature.critical { background-color: \#fb4934; color: \#ffffff; }. Isto fornece um alerta visual eficaz sem necessitar de texto adicional ou de um formato separado (format-critical).  
* **Configuração Avançada (Múltiplos Sensores):** Para monitorizar tanto a CPU como a GPU, é necessário criar múltiplas instâncias do módulo no config.jsonc, cada uma com um identificador único e um hwmon-path específico. Esta é uma funcionalidade poderosa do Waybar que permite a reutilização de módulos.10  
  JSON  
  // Em modules-right (ou outra secção)  
  "modules-right": \[..., "temperature\#cpu", "temperature\#gpu",...\],

  // Definição dos módulos  
  "temperature\#cpu": {  
      "hwmon-path": "/sys/class/hwmon/hwmonX/tempY\_input", // Caminho para o sensor da CPU  
      "format": "CPU: {temperatureC}°C ",  
      "critical-threshold": 85  
  },  
  "temperature\#gpu": {  
      "hwmon-path": "/sys/class/hwmon/hwmonA/tempB\_input", // Caminho para o sensor da GPU  
      "format": "GPU: {temperatureC}°C ",  
      "critical-threshold": 90  
  }

### **Integração Perfeita com o Hyprland**

A força do Waybar no ecossistema Hyprland reside nos seus módulos nativos que se integram diretamente com o compositor, proporcionando uma experiência fluida e reativa.

#### **Espaços de Trabalho (hyprland/workspaces)**

Este módulo é o centro nevrálgico da navegação num gestor de janelas tiling.

* **Configuração:** Uma abordagem minimalista substitui os números dos espaços de trabalho por ícones ou pontos simples. A estilização em style.css é usada para diferenciar visualmente o espaço de trabalho focado (\#workspaces button.focused) dos inativos ou dos que contêm janelas (\#workspaces button.active).10 A configuração pode ser tão simples como  
  "format": "{icon}", onde os ícones são definidos no próprio módulo ou através de CSS. A configuração de on-click e on-scroll para navegar entre os espaços de trabalho é também uma prática comum para uma interação eficiente.18

#### **Título da Janela (hyprland/window)**

Exibir o título da janela ativa pode ser útil, mas títulos longos podem desequilibrar uma barra minimalista.

* **Configuração:** A propriedade max-length é a ferramenta essencial para o minimalismo aqui. Definir um max-length razoável (por exemplo, 50 caracteres) trunca elegantemente os títulos longos, garantindo que o módulo não ocupa um espaço desproporcional na barra.10 O título completo pode ser revelado no  
  tooltip.

### **Técnicas de Estilização Avançadas**

Para além do CSS básico, o Waybar suporta técnicas mais avançadas que permitem um controlo ainda mais fino sobre a aparência, crucial para aperfeiçoar uma estética minimalista.

* **Marcação Pango:** O Waybar suporta a Marcação Pango diretamente nas strings de format dos módulos.10 Isto permite a estilização inline de texto e ícones sem necessidade de modificar o  
  style.css. É particularmente útil para ajustar o tamanho ou a posição vertical de ícones individuais que podem não estar perfeitamente alinhados com o texto.  
  * **Exemplo:** Para aumentar o tamanho de um ícone de bateria e ajustá-lo verticalmente: "format": "{capacity}% \<span font='14' rise='-1000'\>\</span\>". O rise aceita valores em unidades Pango, permitindo um ajuste preciso.19  
* **Seletores CSS Baseados no Estado:** O Waybar adiciona automaticamente classes CSS aos módulos com base no seu estado atual. Esta é uma funcionalidade extremamente poderosa para fornecer feedback visual dinâmico.  
  * **Exemplos:**  
    * \#battery.charging { color: \#859900; } \- Muda a cor do módulo da bateria quando está a carregar.  
    * \#network.disconnected { background-color: \#dc322f; } \- Destaca o módulo de rede com uma cor de aviso quando a ligação é perdida.  
    * \#pulseaudio.muted { color: \#b58900; } \- Altera a cor do ícone de áudio quando está em mudo.  
  * A utilização destes seletores permite que a barra reaja ao estado do sistema de uma forma subtil e informativa, alinhando-se perfeitamente com os princípios do design minimalista.7

## **Parte III: Personalização Avançada com Módulos Scriptados (custom/)**

Esta secção representa o pináculo da personalização do Waybar, onde o utilizador transcende a configuração de módulos pré-existentes para criar as suas próprias funcionalidades. O módulo custom/ é a porta de entrada para uma extensibilidade quase ilimitada, transformando o Waybar de uma simples barra de estado numa interface de utilizador leve e programável.

### **O Módulo custom/: A Sua Porta de Entrada para Possibilidades Infinitas**

O módulo genérico custom/ permite a execução de qualquer script ou comando externo e a exibição do seu resultado na barra. A sua flexibilidade é a chave para integrar informações e funcionalidades que não são cobertas pelos módulos nativos.

* **Análise da Configuração:** A documentação oficial detalha um conjunto de propriedades que governam o comportamento deste módulo.21  
  * exec: O caminho absoluto para o script que será executado. Este é o coração do módulo.21  
  * return-type: Define o formato esperado da saída do script. O valor "json" é o mais poderoso, pois permite que o script retorne dados estruturados (texto, tooltip, classe CSS, percentagem) que o Waybar pode interpretar.21 Se não for especificado, o Waybar espera uma saída de texto simples, ao estilo do i3blocks.  
  * interval: O intervalo de atualização em segundos. Define a frequência com que o script em exec é executado para obter novos dados.  
  * on-click, on-scroll-up, on-scroll-down: Estes são manipuladores de eventos que executam um comando especificado quando o módulo é clicado ou quando se utiliza a roda do rato sobre ele. Isto torna os módulos personalizados interativos.21  
  * exec-if: Uma propriedade de otimização crucial. Executa um comando de verificação e só executa o script principal em exec se o comando de verificação retornar um código de saída de 0 (sucesso). É ideal para módulos que só são relevantes quando uma determinada aplicação está a correr (por exemplo, pgrep spotify), evitando a execução desnecessária de scripts e ocultando o módulo quando não é relevante.21

O poder do módulo custom/ reside num fluxo de trabalho de três etapas: **Aquisição de Dados** (executar um utilitário de linha de comandos como playerctl, curl ou nvidia-smi), **Transformação de Dados** (analisar e formatar a saída bruta usando ferramentas como jq, sed ou awk) e **Apresentação de Dados** (imprimir o resultado final numa estrutura JSON específica que o Waybar compreende). Dominar este processo permite ao utilizador criar um módulo para praticamente qualquer ferramenta de linha de comandos.  
A tabela seguinte define o esquema JSON que os scripts personalizados devem produzir quando return-type: "json" está ativo. Esta é a interface de programação (API) entre o script e o Waybar.

| Chave | Tipo | Descrição | Exemplo |
| :---- | :---- | :---- | :---- |
| "text" | string | O texto principal a ser exibido no módulo na barra. | "24°C " |
| "tooltip" | string | O texto a ser exibido na dica de ferramenta ao passar o cursor. | "Sensação Térmica: 22°C\\nHumidade: 65%" |
| "class" | string/array | A(s) classe(s) CSS a serem aplicadas ao módulo para estilização condicional. | "critical" ou \["playing", "spotify"\] |
| "percentage" | integer | Um valor numérico (0-100) usado para barras de progresso ou para selecionar um ícone de format-icons. | 75 |

### **Guia Prático: Um Módulo de Meteorologia Minimalista**

**Objetivo:** Criar um módulo que exibe um ícone meteorológico e a temperatura atual, com uma previsão detalhada na dica de ferramenta.

#### **Abordagem A: A Via Rápida (Ferramenta Pré-construída)**

Para uma implementação rápida, pode-se utilizar ferramentas como o wttrbar, um módulo personalizado que utiliza o serviço wttr.in.25

* **Instalação:** Instalar o wttrbar através do gestor de pacotes ou compilando a partir do código fonte.  
* **Configuração no config.jsonc:**  
  JSON  
  "custom/weather": {  
      "exec": "wttrbar \--location 'Lisboa' \--custom-indicator '{ICON} {temp\_C}'",  
      "return-type": "json",  
      "interval": 900, // Atualiza a cada 15 minutos  
      "tooltip": true  
  }

  O wttrbar trata internamente da aquisição e formatação dos dados, oferecendo uma solução simples e eficaz.25

#### **Abordagem B: A Via Flexível (Script Personalizado)**

Para um controlo total, a criação de um script shell personalizado é a melhor opção.

1. **Aquisição de Dados:** Utilizar o curl para obter os dados meteorológicos do wttr.in em formato JSON. O parâmetro format=j1 é essencial.25

   curl \-s "wttr.in/Lisboa?format=j1"  
2. **Transformação de Dados:** Utilizar o jq, um processador de JSON de linha de comandos, para extrair os campos relevantes.  
3. **Apresentação de Dados:** Construir o objeto JSON final para o Waybar.  

* **Script Completo (weather.sh):**  
  Bash  
  \#\!/bin/sh

  LOCATION="Lisboa"  
  WEATHER\_DATA=$(curl \-s "wttr.in/${LOCATION}?format=j1")

  if; then  
      echo '{"text": "", "tooltip": "Erro ao obter dados"}'  
      exit 1  
  fi

  TEMP\_C=$(echo "$WEATHER\_DATA" | jq '.current\_condition.temp\_C')  
  FEELS\_LIKE\_C=$(echo "$WEATHER\_DATA" | jq '.current\_condition.FeelsLikeC')  
  WEATHER\_DESC=$(echo "$WEATHER\_DATA" | jq \-r '.current\_condition.weatherDesc.value')

  \# Mapeamento simples de descrição para ícone (pode ser expandido)  
  ICON="" \# Nuvem por defeito  
  case "$WEATHER\_DESC" in  
      \*Sunny\*|\*Clear\*) ICON="" ;;  
      \*Rain\*|\*Shower\*) ICON="" ;;  
      \*Cloudy\*|\*Overcast\*) ICON="" ;;  
      \*Mist\*|\*Fog\*) ICON="🌫" ;;  
  esac

  TEXT="$ICON ${TEMP\_C}°C"  
  TOOLTIP="Sensação: ${FEELS\_LIKE\_C}°C\\n${WEATHER\_DESC}"

  \# Saída em formato JSON para o Waybar  
  printf '{"text": "%s", "tooltip": "%s"}\\n' "$TEXT" "$TOOLTIP"

* **Configuração no config.jsonc:**  
  JSON  
  "custom/weather": {  
      "exec": "\~/.config/waybar/scripts/weather.sh",  
      "return-type": "json",  
      "interval": 900  
  }

### **Guia Prático: Controlo Interativo de Média do Spotify**

**Objetivo:** Criar um módulo que exibe a faixa atual do Spotify, permite controlar a reprodução (play/pause, próxima/anterior) e se oculta automaticamente quando o Spotify não está em execução.

* **Ferramenta Principal:** playerctl, um utilitário de linha de comandos para controlar leitores de média que implementam a interface MPRIS D-Bus, como o Spotify.23  
* **Implementação:**  
  1. **Configuração no config.jsonc:**  
     JSON  
     "custom/spotify": {  
         "format": "{} ",  
         "exec": "\~/.config/waybar/scripts/spotify.sh",  
         "return-type": "json",  
         "exec-if": "pgrep spotify",  
         "on-click": "playerctl \--player=spotify play-pause",  
         "on-scroll-up": "playerctl \--player=spotify next",  
         "on-scroll-down": "playerctl \--player=spotify previous",  
         "max-length": 40  
     }

     A utilização de exec-if é fundamental para a eficiência e para uma interface limpa.23 Os manipuladores  
     on-click e on-scroll fornecem a interatividade desejada.29  
  2. **Script (spotify.sh):** O script verifica o estado do playerctl e formata a saída em conformidade. Baseado em exemplos da comunidade.24  
     Bash  
     \#\!/bin/bash

     PLAYER\_STATUS=$(playerctl \--player=spotify status 2\>/dev/null)

     if; then  
         ARTIST=$(playerctl \--player=spotify metadata artist)  
         TITLE=$(playerctl \--player=spotify metadata title)  
         echo "{\\"text\\": \\"${ARTIST} \- ${TITLE}\\", \\"class\\": \\"playing\\"}"  
     elif; then  
         ARTIST=$(playerctl \--player=spotify metadata artist)  
         TITLE=$(playerctl \--player=spotify metadata title)  
         echo "{\\"text\\": \\" ${ARTIST} \- ${TITLE}\\", \\"class\\": \\"paused\\"}"  
     else  
         echo "{\\"text\\": \\"\\", \\"class\\": \\"stopped\\"}"  
     fi

     Este script retorna não só o texto, mas também uma classe CSS (playing, paused, stopped), permitindo uma estilização diferente para cada estado no style.css.

### **Guia Prático: Monitorização da Temperatura da GPU**

**Objetivo:** Exibir a temperatura atual de uma GPU NVIDIA, um caso de uso comum não coberto por um módulo nativo.

* **Ferramenta Principal:** nvidia-smi, a Interface de Gestão do Sistema da NVIDIA.31  
* **Implementação:**  
  1. Aquisição de Dados: O desafio é extrair apenas o valor numérico da temperatura. O comando nvidia-smi oferece opções de consulta para este fim.  
     nvidia-smi \--query-gpu=temperature.gpu \--format=csv,noheader,nounits  
     Este comando foi derivado de uma análise aprofundada da documentação do nvidia-smi e é a forma mais limpa e fiável de obter apenas o dado necessário.31  
  2. **Script (gpu\_temp.sh):** Um script simples que executa o comando e formata a saída.  
     Bash  
     \#\!/bin/sh

     TEMP=$(nvidia-smi \--query-gpu=temperature.gpu \--format=csv,noheader,nounits)

     if; then  
         echo "{\\"text\\": \\"GPU: ${TEMP}°C\\"}"  
     else  
         echo "{\\"text\\": \\"GPU: N/A\\"}"  
     fi

  3. **Configuração no config.jsonc:**  
     JSON  
     "custom/gpu-temp": {  
         "exec": "\~/.config/waybar/scripts/gpu\_temp.sh",  
         "return-type": "json",  
         "interval": 10 // Atualiza a cada 10 segundos  
     }

  * **Alternativa:** Para utilizadores que preferem não criar scripts, existem ferramentas pré-construídas como gpu-usage-waybar que oferecem uma funcionalidade semelhante com uma configuração mais simples.33

## **Parte IV: Tipografia, Iconografia e Resolução Abrangente de Problemas**

Esta secção aborda os aspetos práticos e os desafios mais comuns na personalização do Waybar, fornecendo soluções claras e acionáveis para garantir uma experiência de configuração suave e bem-sucedida.

### **O Ecossistema Nerd Fonts: Um Pré-requisito para o "Ricing" Moderno**

A utilização de ícones é um pilar da estética minimalista e funcional no Waybar. Em vez de depender de ficheiros de imagem, a comunidade adotou massivamente as Nerd Fonts como a solução padrão para iconografia.

* **O que são Nerd Fonts?** Nerd Fonts é um projeto que pega em fontes populares de programação (como Fira Code, JetBrains Mono, Iosevka) e adiciona-lhes milhares de glifos (ícones) de coleções icónicas como Font Awesome, Devicons, Material Design Icons e Weather Icons.34 O resultado é uma única fonte que contém tanto caracteres de texto como um vasto leque de símbolos, simplificando enormemente a configuração.  
* **Seleção da Fonte e as Suas Variantes:** Um ponto crítico, e frequentemente uma fonte de confusão, é a existência de diferentes variantes para cada Nerd Font. A escolha da variante tem um impacto direto na renderização dos ícones.  
  * **Mono:** Nesta variante, todos os glifos, incluindo os ícones, são forçados a ocupar a mesma largura horizontal de um caractere de texto padrão. Como muitos ícones são naturalmente mais largos do que altos, isto resulta frequentemente em ícones que parecem desproporcionalmente pequenos e espremidos.19  
  * **Propo (Proporcional):** Esta variante permite que os glifos tenham larguras variáveis. Os ícones podem ocupar o espaço horizontal de que necessitam, resultando numa aparência mais equilibrada e no tamanho correto. Para utilização no Waybar, a variante **Proporcional é geralmente a escolha recomendada**.19  
* **Instalação:** O processo de instalação é padronizado na maioria das distribuições Linux:  
  1. Descarregar a variante de fonte desejada do site oficial Nerd Fonts.35  
  2. Mover os ficheiros da fonte (geralmente .ttf ou .otf) para o diretório de fontes do utilizador: \~/.local/share/fonts/.  
  3. Reconstruir a cache de fontes do sistema para que as novas fontes sejam reconhecidas. O comando para isto é fc-cache \-fv.34

### **Guia de Resolução de Problemas Abrangente**

A personalização do Waybar, especialmente com ícones e scripts, pode apresentar desafios. A análise de discussões da comunidade revela um conjunto de problemas recorrentes. Esta secção consolida esse conhecimento disperso num guia de diagnóstico estruturado.  
Os problemas com a renderização de Nerd Fonts são uma das queixas mais frequentes, com sintomas como ícones que não aparecem (exibidos como quadrados, conhecidos como "tofu"), que aparecem com o símbolo errado ou que são demasiado pequenos. A causa subjacente raramente é única, exigindo uma abordagem de diagnóstico sistemática.

1. **Causa Provável: Escolha da Variante da Fonte.** Como detalhado anteriormente, a utilização de uma variante Mono é a causa mais comum para ícones pequenos.  
2. **Causa Provável: Configuração CSS.** A ordem das fontes na propriedade font-family no style.css funciona como uma lista de fallback. Se uma fonte que não é Nerd Font estiver listada primeiro, o sistema pode tentar renderizar o ícone com essa fonte, falhar e não prosseguir para a Nerd Font na lista.  
3. **Causa Provável: Peculiaridade de Renderização.** Vários utilizadores relatam que adicionar um simples espaço após um ícone na string format do módulo faz com que este seja renderizado no tamanho correto. Isto aponta para um comportamento de baixo nível do motor de renderização de fontes.19  
4. **Causa Provável: Glifos Desatualizados.** As versões mais recentes das Nerd Fonts (v3 e posteriores) removeram alguns glifos mais antigos. Se uma configuração for copiada de um guia mais antigo, pode estar a referenciar códigos de glifos que já não existem na versão da fonte instalada.38

A matriz seguinte sistematiza este processo de diagnóstico.

| Sintoma | Causa Potencial | Solução | Fontes Relevantes |
| :---- | :---- | :---- | :---- |
| **Ícones demasiado pequenos** | Utilização de uma variante Mono da Nerd Font. | 1\. Mudar para a variante Propo da mesma fonte. 2\. (Alternativa) Usar Marcação Pango para definir o tamanho manualmente: \<span font='16'\>ICON\</span\>. | 19 |
| **Ícones ainda pequenos/desalinhados** | Peculiaridade do motor de renderização. | Adicionar um espaço em branco após o ícone na string format (ex: "format": " " ). | 19 |
| **Ícones como quadrados ("tofu") ou símbolo errado** | Ordem incorreta de font-family no CSS. | Assegurar que a Nerd Font é a primeira entrada na lista font-family no style.css. Ex: font-family: "JetBrainsMono Nerd Font", sans-serif;. | 38 |
| **Ícones como quadrados (continua)** | Fonte em falta, desatualizada ou glifo incorreto. | 1\. Verificar se a fonte está corretamente instalada (fc-list \| grep "NomeDaFonte"). 2\. Consultar a "cheat sheet" oficial das Nerd Fonts para verificar se o código do glifo existe na sua versão. | 38 |

### **Depuração de Scripts Personalizados**

Quando um módulo custom/ não funciona como esperado, a depuração deve seguir um processo lógico para isolar o problema.42

#### **Ponto de Falha 1: O Módulo Não Aparece ou Não Tem Saída**

* **Causa:** O script não é executável.  
  * **Solução:** Conceder permissões de execução com chmod \+x \~/.config/waybar/scripts/seu\_script.sh.  
* **Causa:** O caminho no exec está incorreto ou é relativo.  
  * **Solução:** Utilizar sempre caminhos absolutos para os scripts (ex: /home/user/.config/... ou \~/.config/...).  
* **Causa:** Buffering da saída em scripts contínuos (comum em Python). O script está a gerar saída, mas esta não é enviada imediatamente para o Waybar.  
  * **Solução:** Forçar o "flush" do buffer de saída. Em Python 3, isto é feito facilmente com print("...", flush=True).42

#### **Ponto de Falha 2: O Módulo Aparece, mas Vazio ou com Erro**

* **Causa:** A saída do script não é um JSON válido (quando return-type: "json" é usado). Um erro comum é a falta de aspas em strings ou caracteres especiais não escapados.  
  * **Solução:** Executar o script manualmente no terminal e validar a sua saída. Ferramentas como o jq são excelentes para isto. Se seu\_script.sh | jq produzir um erro, o JSON está malformado.24

#### **Técnica de Depuração Geral**

* **Executar o Waybar a partir do Terminal:** A forma mais eficaz de diagnosticar problemas é fechar a instância existente do Waybar (killall waybar) e iniciá-la a partir de um terminal. O Waybar imprimirá avisos e erros diretamente no terminal. Para uma depuração ainda mais detalhada, utilize o nível de log de "trace": waybar \-l trace. Esta saída geralmente aponta para a linha de configuração exata ou o script que está a causar o problema.43

## **Parte V: Síntese, Inspiração e o Ecossistema Mais Amplo**

Esta secção final consolida os conceitos abordados através da análise de exemplos do mundo real, posiciona o Waybar no contexto de outras alternativas e fornece um roteiro claro para que o utilizador inicie a sua própria jornada de personalização.

### **Análise de "Dotfiles" Selecionados: Da Teoria à Prática**

A melhor forma de compreender a aplicação dos princípios discutidos é analisar configurações completas e bem documentadas da comunidade. Estes repositórios de "dotfiles" servem como fontes de inspiração e exemplos práticos.

#### **Estudo de Caso 1: mylinuxforwork/dotfiles (Funcional e Completo)**

* **Análise:** Este repositório foca-se em fornecer uma experiência de desktop Hyprland completa e avançada, com temas de cores materiais adaptativos baseados no papel de parede.44  
  * **Estética:** O objetivo é um ambiente de trabalho funcional e esteticamente agradável, mas não estritamente minimalista no sentido de "poucos elementos". O minimalismo aqui manifesta-se na coesão do design e na organização lógica da informação.  
  * **config.jsonc:** A configuração provavelmente utiliza um conjunto completo de módulos para monitorizar todos os aspetos do sistema, organizados de forma lógica nas secções esquerda, central e direita.  
  * **style.css:** O CSS é uma parte significativa deste projeto (34.2% da base de código em CSS), indicando uma estilização profunda para alcançar temas de cores dinâmicos que se sincronizam com o resto do ambiente.44  
  * **Scripts Personalizados:** A natureza "completa" sugere a utilização de scripts personalizados para funcionalidades que vão além dos módulos padrão, integrando-se com o ecossistema de aplicações selecionado.

#### **Estudo de Caso 2: end-4/dots-hyprland (Inovador e Centrado no Design)**

* **Análise:** Este projeto adota uma abordagem radicalmente diferente, evitando o Waybar por completo e utilizando um sistema de widgets personalizado chamado Quickshell, baseado em QtQuick.45  
  * **Estética:** A inspiração vem do Windows 11, Material Design 3 e conceitos de design modernos, com um forte foco em animações fluidas e cores geradas automaticamente.  
  * **Relevância:** Embora não utilize o Waybar, a análise deste projeto é valiosa porque demonstra os limites do que pode ser alcançado em termos de interface de utilizador no Hyprland. Serve como uma fonte de inspiração para o que é visualmente possível, e os princípios de design (cores baseadas no papel de parede, pré-visualizações ao vivo de janelas) podem ser adaptados, ainda que de forma mais simples, para configurações do Waybar.

#### **Estudo de Caso 3: Repositórios da Comunidade (Minimalistas e Focados)**

* **Análise:** A exploração de tópicos no GitHub como "hyprland-dotfiles" revela inúmeros projetos mais pequenos e focados, que são excelentes para encontrar exemplos concisos de configurações minimalistas do Waybar.46  
  * **Padrões Comuns:** Muitos destes repositórios partilham uma estrutura semelhante: um config.jsonc com um número reduzido de módulos (frequentemente hyprland/workspaces, clock, pulseaudio, tray), um style.css que implementa uma das estéticas descritas na Parte I (flutuante, plano ou em pílulas), e um ou dois scripts personalizados para funcionalidades específicas, como o controlo de média com playerctl.49

### **O Ecossistema de Painéis Wayland: Uma Breve Visão Geral**

O Waybar é uma escolha extremamente popular, mas não é a única. Compreender as alternativas ajuda a contextualizar os seus pontos fortes e fracos.53

* **AGS (Aylur's GTK Shell):** Mais do que uma barra de estado, o AGS é um framework para criar widgets e elementos de shell para Wayland usando JavaScript ou TypeScript e GTK.54  
  * **Vantagens:** Flexibilidade e poder quase ilimitados. Permite criar interfaces complexas, como centros de controlo e dashboards, que vão muito além das capacidades do Waybar. Integração nativa com serviços como Hyprland e Mpris.54  
  * **Desvantagens:** Curva de aprendizagem significativamente mais acentuada. Requer conhecimentos de programação em JavaScript/TypeScript e familiaridade com o ecossistema GJS/GTK.  
* **EWW (ElKowar's Wacky Widgets):** Um sistema de widgets altamente personalizável que utiliza uma linguagem de configuração própria, semelhante a Lisp, e SCSS para estilização.57  
  * **Vantagens:** Extremamente flexível, permitindo a criação de qualquer tipo de widget. A configuração em Lisp é considerada simples por alguns, e o suporte nativo a SCSS é um ponto forte.58  
  * **Desvantagens:** Requer a aprendizagem de uma sintaxe de configuração única, o que pode ser uma barreira para novos utilizadores.57  
* **nwg-panel:** Parte de um conjunto maior de ferramentas (nwg-shell), este painel baseado em GTK oferece uma abordagem mais tradicional e é frequentemente configurável através de uma interface gráfica.59  
  * **Vantagens:** Mais fácil de configurar para iniciantes, graças às ferramentas gráficas. Oferece um conjunto de módulos bem integrados.59  
  * **Desvantagens:** Menos flexível e "programável" do que o Waybar, AGS ou EWW. A personalização está mais limitada às opções fornecidas.

A análise comparativa posiciona o Waybar num ponto estratégico do ecossistema. É significativamente mais poderoso e personalizável do que painéis mais simples como o nwg-panel, mas menos complexo de configurar do que frameworks de widgets completos como o AGS ou o EWW. A sua dependência de formatos de configuração familiares (JSON, CSS) e de scripts shell torna-o a escolha ideal para o "power user" de Linux que valoriza a extensibilidade e o controlo granular sem a necessidade de aprender uma linguagem de programação de GUI completa ou um framework complexo.

### **Conclusão: Um Roteiro para a Sua Personalização Pessoal**

Este guia forneceu uma análise exaustiva das ferramentas, técnicas e princípios necessários para criar uma configuração Waybar minimalista, funcional e esteticamente agradável no Hyprland. Desde os fundamentos do design e da configuração global até à criação de módulos personalizados interativos e à resolução de problemas comuns, o caminho para uma personalização profunda foi delineado.  
Para o utilizador que deseja iniciar a sua própria jornada de "ricing", recomenda-se o seguinte fluxo de trabalho iterativo:

1. **Começar com o Mínimo:** Inicie com um ficheiro config.jsonc mínimo, contendo apenas os módulos mais essenciais, como hyprland/workspaces e clock, para estabelecer uma base funcional.10  
2. **Definir a Estética:** Crie o ficheiro style.css e defina a aparência global da barra. Decida sobre uma estética (flutuante, plana, etc.) e implemente as regras CSS fundamentais para o fundo, margens, fontes e cores.  
3. **Configurar Módulos Nativos:** Adicione e configure os módulos nativos essenciais (como pulseaudio, network, battery) um de cada vez, aplicando os princípios minimalistas de hierarquia da informação (utilizando tooltip e format-alt) e estilização baseada no estado.  
4. **Identificar e Implementar Módulos Personalizados:** Identifique uma funcionalidade que falta e que seria valiosa para o seu fluxo de trabalho (por exemplo, controlo de média, meteorologia). Construa um módulo custom/ seguindo o processo de três etapas: **Adquirir** os dados com uma ferramenta de linha de comandos, **Transformar** a saída para um formato útil e **Apresentar** o resultado em JSON para o Waybar.  
5. **Iterar e Refinar:** A personalização é um processo contínuo. Refine os seus scripts, ajuste os seus estilos CSS e explore a vasta gama de possibilidades que a comunidade e as ferramentas disponíveis oferecem.

Ao seguir esta abordagem estruturada, a criação de um "rice" deixa de ser uma tarefa intimidante e torna-se um exercício gratificante de expressão pessoal e otimização de fluxo de trabalho.

#### **Referências citadas**

1. \[Niri\] An Overview to My Waybar : r/unixporn \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/unixporn/comments/1mz7x0s/niri\_an\_overview\_to\_my\_waybar/](https://www.reddit.com/r/unixporn/comments/1mz7x0s/niri_an_overview_to_my_waybar/)  
2. \[Hyprland\] With waybar Minimal and clean with pywal16 : r/unixporn \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/unixporn/comments/1blvmpc/hyprland\_with\_waybar\_minimal\_and\_clean\_with/](https://www.reddit.com/r/unixporn/comments/1blvmpc/hyprland_with_waybar_minimal_and_clean_with/)  
3. \[Hyprland\] Minimal or powerful bar? Well, BOTH\! : r/unixporn \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/unixporn/comments/1kjwv1n/hyprland\_minimal\_or\_powerful\_bar\_well\_both/](https://www.reddit.com/r/unixporn/comments/1kjwv1n/hyprland_minimal_or_powerful_bar_well_both/)  
4. \[Sway\] New to this whole "minimalism" thing, how'd I do? : r/unixporn \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/unixporn/comments/1mm4196/sway\_new\_to\_this\_whole\_minimalism\_thing\_howd\_i\_do/](https://www.reddit.com/r/unixporn/comments/1mm4196/sway_new_to_this_whole_minimalism_thing_howd_i_do/)  
5. \[Hyprland\] fun with widget with physics : r/unixporn \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/unixporn/comments/1mwc72y/hyprland\_fun\_with\_widget\_with\_physics/](https://www.reddit.com/r/unixporn/comments/1mwc72y/hyprland_fun_with_widget_with_physics/)  
6. \[Hyprland\] Created a style selector for my waybar theme : r/unixporn \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/unixporn/comments/1iwsdt9/hyprland\_created\_a\_style\_selector\_for\_my\_waybar/](https://www.reddit.com/r/unixporn/comments/1iwsdt9/hyprland_created_a_style_selector_for_my_waybar/)  
7. waybar style.css for minimalist desktop \- GitHub Gist, acessado em agosto 29, 2025, [https://gist.github.com/bnema/b381f24617b7ac4e05fd71c59fbe7e18](https://gist.github.com/bnema/b381f24617b7ac4e05fd71c59fbe7e18)  
8. waybar style minimalist \- GitHub Gist, acessado em agosto 29, 2025, [https://gist.github.com/bnema/1b410021e5d2f2be8b9b1db11533c6a2](https://gist.github.com/bnema/1b410021e5d2f2be8b9b1db11533c6a2)  
9. Install and Configure Waybar in Hyprland \- It's FOSS, acessado em agosto 29, 2025, [https://itsfoss.com/configure-waybar/](https://itsfoss.com/configure-waybar/)  
10. waybar(5) \- Arch Linux manual pages, acessado em agosto 29, 2025, [https://man.archlinux.org/man/waybar.5.en](https://man.archlinux.org/man/waybar.5.en)  
11. Waybar CSS Help : r/hyprland \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/hyprland/comments/1abrybs/waybar\_css\_help/](https://www.reddit.com/r/hyprland/comments/1abrybs/waybar_css_help/)  
12. waybar-clock(5) — Arch manual pages, acessado em agosto 29, 2025, [https://man.archlinux.org/man/extra/waybar/waybar-clock.5.en](https://man.archlinux.org/man/extra/waybar/waybar-clock.5.en)  
13. waybar-temperature(5) — Arch manual pages, acessado em agosto 29, 2025, [https://man.archlinux.org/man/extra/waybar/waybar-temperature.5.en](https://man.archlinux.org/man/extra/waybar/waybar-temperature.5.en)  
14. waybar \- clock module \- Ubuntu Manpage, acessado em agosto 29, 2025, [https://manpages.ubuntu.com/manpages/jammy/man5/waybar-clock.5.html](https://manpages.ubuntu.com/manpages/jammy/man5/waybar-clock.5.html)  
15. waybar-clock(5) \- f33 \- MANPATH.be, acessado em agosto 29, 2025, [http://manpath.be/f33/5/waybar-clock](http://manpath.be/f33/5/waybar-clock)  
16. waybar-pulseaudio(5) — Arch manual pages, acessado em agosto 29, 2025, [https://man.archlinux.org/man/extra/waybar/waybar-pulseaudio.5.en](https://man.archlinux.org/man/extra/waybar/waybar-pulseaudio.5.en)  
17. waybar \- temperature module \- Ubuntu Manpage, acessado em agosto 29, 2025, [https://manpages.ubuntu.com/manpages/focal/man5/waybar-temperature.5.html](https://manpages.ubuntu.com/manpages/focal/man5/waybar-temperature.5.html)  
18. home/desktop/waybar.nix · de5afef8a44959d84bfe5df9b704837587a983de · Nicolas Lenz / NixOS · GitLab \- Explore projects, acessado em agosto 29, 2025, [https://gitlab.fachschaften.org/nicolas.lenz/nixos/-/blob/de5afef8a44959d84bfe5df9b704837587a983de/home/desktop/waybar.nix](https://gitlab.fachschaften.org/nicolas.lenz/nixos/-/blob/de5afef8a44959d84bfe5df9b704837587a983de/home/desktop/waybar.nix)  
19. How can i make nerd font icons larger in waybar? : r/hyprland \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/hyprland/comments/1bkbeac/how\_can\_i\_make\_nerd\_font\_icons\_larger\_in\_waybar/](https://www.reddit.com/r/hyprland/comments/1bkbeac/how_can_i_make_nerd_font_icons_larger_in_waybar/)  
20. Nerdfont glyphs too small on Waybar : r/voidlinux \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/voidlinux/comments/10o6yql/nerdfont\_glyphs\_too\_small\_on\_waybar/](https://www.reddit.com/r/voidlinux/comments/10o6yql/nerdfont_glyphs_too_small_on_waybar/)  
21. waybar-custom(5) \- Arch Linux manual pages, acessado em agosto 29, 2025, [https://man.archlinux.org/man/extra/waybar/waybar-custom.5.en](https://man.archlinux.org/man/extra/waybar/waybar-custom.5.en)  
22. Waybar/man/waybar-custom.5.scd at master · Alexays/Waybar \- GitHub, acessado em agosto 29, 2025, [https://github.com/Alexays/Waybar/blob/master/man/waybar-custom.5.scd](https://github.com/Alexays/Waybar/blob/master/man/waybar-custom.5.scd)  
23. Waybar Media Display Module using playerctl \- Lib.rs, acessado em agosto 29, 2025, [https://lib.rs/crates/waybar\_media\_display](https://lib.rs/crates/waybar_media_display)  
24. Spotify Script Example · Issue \#34 · Alexays/Waybar · GitHub, acessado em agosto 29, 2025, [https://github.com/Alexays/Waybar/issues/34](https://github.com/Alexays/Waybar/issues/34)  
25. bjesus/wttrbar: Custom module for showing the weather in Waybar, using the great wttr.in \- GitHub, acessado em agosto 29, 2025, [https://github.com/bjesus/wttrbar](https://github.com/bjesus/wttrbar)  
26. Help \- wttr.in, acessado em agosto 29, 2025, [https://wttr.in/:help](https://wttr.in/:help)  
27. \[SOLVED\] Dbus music control. / Applications & Desktop Environments / Arch Linux Forums, acessado em agosto 29, 2025, [https://bbs.archlinux.org/viewtopic.php?id=298342](https://bbs.archlinux.org/viewtopic.php?id=298342)  
28. altdesktop/playerctl: mpris media player command-line ... \- GitHub, acessado em agosto 29, 2025, [https://github.com/altdesktop/playerctl](https://github.com/altdesktop/playerctl)  
29. \[WAYBAR\] Custom waybar spotify module stopped showing up : r/hyprland \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/hyprland/comments/1b6ga81/waybar\_custom\_waybar\_spotify\_module\_stopped/](https://www.reddit.com/r/hyprland/comments/1b6ga81/waybar_custom_waybar_spotify_module_stopped/)  
30. Scrolling text · Alexays Waybar · Discussion \#2006 \- GitHub, acessado em agosto 29, 2025, [https://github.com/Alexays/Waybar/discussions/2006](https://github.com/Alexays/Waybar/discussions/2006)  
31. System Management Interface SMI | NVIDIA Developer, acessado em agosto 29, 2025, [https://developer.nvidia.com/system-management-interface](https://developer.nvidia.com/system-management-interface)  
32. Nvidia-smi Manual, acessado em agosto 29, 2025, [https://docs.nvidia.com/deploy/nvidia-smi/index.html](https://docs.nvidia.com/deploy/nvidia-smi/index.html)  
33. gpu-usage-waybar — Rust application // Lib.rs, acessado em agosto 29, 2025, [https://lib.rs/crates/gpu-usage-waybar](https://lib.rs/crates/gpu-usage-waybar)  
34. Installing Nerd Fonts \- Documentation, acessado em agosto 29, 2025, [https://docs.rockylinux.org/books/nvchad/nerd\_fonts/](https://docs.rockylinux.org/books/nvchad/nerd_fonts/)  
35. Nerd Fonts \- Iconic font aggregator, glyphs/icons collection, & fonts ..., acessado em agosto 29, 2025, [https://www.nerdfonts.com/](https://www.nerdfonts.com/)  
36. \[SOLVED\] Font icons of weird size larger then selection / Newbie Corner / Arch Linux Forums, acessado em agosto 29, 2025, [https://bbs.archlinux.org/viewtopic.php?id=279845](https://bbs.archlinux.org/viewtopic.php?id=279845)  
37. Small icons on waybar in hyprland, how do I install symbol only nerd fonts? \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/Fedora/comments/1m16wko/small\_icons\_on\_waybar\_in\_hyprland\_how\_do\_i/](https://www.reddit.com/r/Fedora/comments/1m16wko/small_icons_on_waybar_in_hyprland_how_do_i/)  
38. Waybar icons missing : r/Gentoo \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/Gentoo/comments/1jy73dy/waybar\_icons\_missing/](https://www.reddit.com/r/Gentoo/comments/1jy73dy/waybar_icons_missing/)  
39. Font icons aren't properly shown in waybar? : r/swaywm \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/swaywm/comments/rsp7rm/font\_icons\_arent\_properly\_shown\_in\_waybar/](https://www.reddit.com/r/swaywm/comments/rsp7rm/font_icons_arent_properly_shown_in_waybar/)  
40. Font Awesome icons get smaller after installing Nerd Font \- Arch Linux Forums, acessado em agosto 29, 2025, [https://bbs.archlinux.org/viewtopic.php?id=254178](https://bbs.archlinux.org/viewtopic.php?id=254178)  
41. Why is getting the icon fonts in waybar so complicated? : r/swaywm \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/swaywm/comments/178n24t/why\_is\_getting\_the\_icon\_fonts\_in\_waybar\_so/](https://www.reddit.com/r/swaywm/comments/178n24t/why_is_getting_the_icon_fonts_in_waybar_so/)  
42. Custom Waybar Module Not Displaying Text : r/swaywm \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/swaywm/comments/vd1lwp/custom\_waybar\_module\_not\_displaying\_text/](https://www.reddit.com/r/swaywm/comments/vd1lwp/custom_waybar_module_not_displaying_text/)  
43. Waybar custom module issue "Argument not found" : r/swaywm \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/swaywm/comments/1any425/waybar\_custom\_module\_issue\_argument\_not\_found/](https://www.reddit.com/r/swaywm/comments/1any425/waybar_custom_module_issue_argument_not_found/)  
44. mylinuxforwork/dotfiles: The ML4W Dotfiles for Hyprland ... \- GitHub, acessado em agosto 29, 2025, [https://github.com/mylinuxforwork/dotfiles](https://github.com/mylinuxforwork/dotfiles)  
45. end-4/dots-hyprland: Rice built for usability \- GitHub, acessado em agosto 29, 2025, [https://github.com/end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)  
46. hyprland-dotfiles · GitHub Topics, acessado em agosto 29, 2025, [https://github.com/topics/hyprland-dotfiles?l=css](https://github.com/topics/hyprland-dotfiles?l=css)  
47. hyprland · GitHub Topics, acessado em agosto 29, 2025, [https://github.com/topics/hyprland](https://github.com/topics/hyprland)  
48. myamusashi/hyprlandots: Dotfiles hyprland \- GitHub, acessado em agosto 29, 2025, [https://github.com/myamusashi/hyprlandots](https://github.com/myamusashi/hyprlandots)  
49. rchrdwllm/dotfiles \- GitHub, acessado em agosto 29, 2025, [https://github.com/rchrdwllm/dotfiles](https://github.com/rchrdwllm/dotfiles)  
50. momcilovicluka/Hyprland-dots: Dotfiles for my Arch Hyprland setup. \- GitHub, acessado em agosto 29, 2025, [https://github.com/momcilovicluka/Hyprland-dots](https://github.com/momcilovicluka/Hyprland-dots)  
51. develcooking/hyprland-dotfiles \- GitHub, acessado em agosto 29, 2025, [https://github.com/develcooking/hyprland-dotfiles](https://github.com/develcooking/hyprland-dotfiles)  
52. kaii-lb/dotfiles: My dotfiles for hyprland \- GitHub, acessado em agosto 29, 2025, [https://github.com/kaii-lb/dotfiles](https://github.com/kaii-lb/dotfiles)  
53. What are some alternatives to waybar? : r/hyprland \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/hyprland/comments/1kw6phi/what\_are\_some\_alternatives\_to\_waybar/](https://www.reddit.com/r/hyprland/comments/1kw6phi/what_are_some_alternatives_to_waybar/)  
54. Hyprland | AGS Wiki \- GitHub Pages, acessado em agosto 29, 2025, [https://aylur.github.io/ags-docs/services/hyprland/](https://aylur.github.io/ags-docs/services/hyprland/)  
55. \[Hyprland\] What else should I add? : r/unixporn \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/unixporn/comments/15k5qpv/hyprland\_what\_else\_should\_i\_add/](https://www.reddit.com/r/unixporn/comments/15k5qpv/hyprland_what_else_should_i_add/)  
56. \[Hyprland\] My ags config starting to shape up. Still a lot of work to do, only the bar finished for now. : r/unixporn \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/unixporn/comments/1dqg50y/hyprland\_my\_ags\_config\_starting\_to\_shape\_up\_still/](https://www.reddit.com/r/unixporn/comments/1dqg50y/hyprland_my_ags_config_starting_to_shape_up_still/)  
57. \[Hyprland\] My setup is so eww\! : r/unixporn \- Reddit, acessado em agosto 29, 2025, [https://www.reddit.com/r/unixporn/comments/1mr32zo/hyprland\_my\_setup\_is\_so\_eww/](https://www.reddit.com/r/unixporn/comments/1mr32zo/hyprland_my_setup_is_so_eww/)  
58. Status bars \- Hyprland Wiki, acessado em agosto 29, 2025, [https://wiki.hypr.land/Useful-Utilities/Status-Bars/](https://wiki.hypr.land/Useful-Utilities/Status-Bars/)  
59. nwg-panel | nwg-shell, acessado em agosto 29, 2025, [https://nwg-piotr.github.io/nwg-shell/nwg-panel.html](https://nwg-piotr.github.io/nwg-shell/nwg-panel.html)  
60. Installer & meta-package for the nwg-shell project: a GTK3-based shell for sway and Hyprland Wayland compositors, acessado em agosto 29, 2025, [https://nwg-piotr.github.io/nwg-shell/](https://nwg-piotr.github.io/nwg-shell/)  
61. nwg-shell \- ArchWiki, acessado em agosto 29, 2025, [https://wiki.archlinux.org/title/Nwg-shell](https://wiki.archlinux.org/title/Nwg-shell)
