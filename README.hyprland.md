
# **De Usuário a Arquiteto: Um Guia Exaustivo para a Transição do GNOME para o Hyprland**

---

## **Seção 1: Deconstruindo o Desktop: A Mudança de Paradigma do GNOME para o Hyprland**

A transição de um ambiente de desktop (DE) como o GNOME para um compositor Wayland de janelas em mosaico (tiling window manager) como o Hyprland representa mais do que uma simples mudança de interface; é uma fundamental alteração na filosofia de como um usuário interage com seu sistema operacional. Após anos de familiaridade com a experiência coesa e integrada do GNOME, embarcar na jornada do Hyprland é assumir o papel de arquiteto do seu próprio ambiente digital, trocando a conveniência de um sistema pré-fabricado pela liberdade de construir um espaço de trabalho sob medida.

### **1.1. Além da Interface: A Diferença Filosófica entre DE e WM**

A distinção mais crucial entre GNOME e Hyprland reside em sua abordagem fundamental ao ambiente de desktop. O GNOME é um *produto* completo: um ecossistema integrado de aplicações e serviços projetados para funcionar em harmonia, oferecendo uma experiência de usuário consistente e pronta para uso logo após a instalação.1 Ele inclui um gerenciador de janelas, painel, lançador de aplicativos, tela de login, gerenciador de arquivos e um conjunto de utilitários, todos governados por uma filosofia de design coesa e, por vezes, opinativa.1 A personalização é possível, mas ocorre dentro dos limites estabelecidos pelos desenvolvedores do GNOME, frequentemente através de um sistema de extensões que pode ser frágil e sujeito a quebras entre atualizações de versão.3  
Em contraste, o Hyprland é uma *fundação*. Ele não é um ambiente de desktop completo, mas sim um componente central e altamente especializado: um compositor Wayland e um gerenciador de janelas dinâmico em mosaico.4 Sozinho, o Hyprland fornece apenas a lógica para organizar e exibir janelas na tela. Ele não vem com uma barra de status, um lançador de aplicativos, um daemon de notificações ou um gerenciador de papel de parede.4 Cada uma dessas funcionalidades deve ser escolhida, instalada e configurada individualmente pelo usuário. Essa abordagem modular, "à la carte", é a fonte de sua maior força e de sua curva de aprendizado mais íngreme.  
Essa diferença filosófica tem uma consequência direta e profunda: a natureza modular do Hyprland é a causa direta da vibrante cultura de "ricing" (personalização estética) e do ecossistema de "dotfiles" (arquivos de configuração). Como o sistema base oferece apenas o essencial, a comunidade preenche o vácuo criando e compartilhando configurações completas. A configuração, sendo baseada em arquivos de texto simples (.conf, .css), é facilmente versionável e compartilhável via Git. Portanto, a filosofia "faça você mesmo" do Hyprland gera organicamente uma cultura onde compartilhar dotfiles não é apenas para exibição, mas uma necessidade funcional para ajudar novos usuários a começar.6 Ao escolher o Hyprland, o usuário não está apenas selecionando um software, mas ingressando em uma cultura de construção, personalização e compartilhamento.  
A tabela a seguir resume as principais diferenças entre os dois paradigmas:

| Característica | GNOME | Hyprland | Implicações para o Usuário |
| :---- | :---- | :---- | :---- |
| **Filosofia** | Integrado ("Produto") | Modular ("Fundação") | GNOME oferece conveniência imediata; Hyprland exige construção ativa do ambiente. |
| **Gerenciamento de Janelas** | Flutuante (Floating) | Mosaico Dinâmico (Dynamic Tiling) | GNOME segue um modelo tradicional; Hyprland organiza janelas automaticamente em grades para maximizar o espaço. |
| **Configuração** | GUI e dconf/gsettings | Arquivos de texto (hyprland.conf) | A configuração do GNOME é mais visual e limitada; a do Hyprland é textual, poderosa e totalmente granular. |
| **Componentes** | Inclusos (barra, notificações, etc.) | "À la carte" (escolha individual) | Nenhuma decisão de software é necessária no GNOME; no Hyprland, o usuário deve escolher e integrar cada componente. |
| **Curva de Aprendizagem** | Baixa | Alta | GNOME é intuitivo para iniciantes; Hyprland requer tempo e disposição para aprender a configurar o sistema do zero. |

### **1.2. O Papel do Wayland: O Coração Moderno do Hyprland**

Tanto o GNOME moderno quanto o Hyprland utilizam o Wayland, o protocolo de servidor gráfico que sucede o antigo X11.8 No entanto, suas implementações e o grau de adesão às tecnologias mais recentes diferem. O Wayland simplifica a arquitetura gráfica do Linux ao fundir as responsabilidades do servidor de exibição, do gerenciador de janelas e do compositor em uma única entidade: o compositor Wayland.4  
O Hyprland é construído sobre o wlroots, uma biblioteca modular para criar compositores Wayland, e se destaca por implementar agressivamente os recursos mais recentes e avançados do protocolo, como suporte a gestos de touchpad, animações baseadas em curvas de Bézier e efeitos visuais sofisticados como o desfoque Dual-Kawase.11 Ele segue de perto o desenvolvimento do  
wlroots-git, garantindo que os usuários tenham acesso quase imediato às últimas inovações do ecossistema Wayland.13 Essa abordagem "bleeding-edge" é um dos seus principais atrativos, oferecendo uma experiência visual fluida e responsiva que muitos consideram o estado da arte no desktop Linux.11

### **1.3. O que Esperar: Liberdade, Controle e a Curva de Aprendizagem**

A transição do GNOME para o Hyprland é uma troca deliberada de conveniência por controle. A experiência inicial pode ser desconcertante: após a instalação e o primeiro login, o usuário é frequentemente saudado por uma tela preta e um cursor, sem menus, ícones ou barras de tarefas.8 Este é o ponto de partida. A partir daqui, cada elemento visual e funcional deve ser adicionado e configurado manualmente.4  
Esta jornada exige familiaridade com a linha de comando e a disposição para ler documentação e editar arquivos de configuração.8 A curva de aprendizado é inegavelmente íngreme.14 No entanto, o retorno sobre esse investimento de tempo é imenso. O usuário ganha um controle sem precedentes sobre cada aspecto do seu ambiente, desde a velocidade de uma animação de janela até o comportamento exato de um aplicativo ao abrir. O resultado final não é apenas um desktop personalizado, mas um  
*workflow* otimizado, projetado pelo próprio usuário para maximizar sua eficiência e conforto.4 A liberdade oferecida pelo Hyprland é a liberdade de construir uma ferramenta perfeitamente adaptada às suas necessidades, um poder que ambientes integrados como o GNOME, por sua própria natureza, não podem oferecer no mesmo grau.2

## **Seção 2: A Fundação: Instalando e Iniciando o Hyprland**

A instalação do Hyprland é o primeiro passo prático na construção do novo ambiente de trabalho. A escolha da distribuição Linux e o método de instalação são decisões cruciais que impactam diretamente a estabilidade e a facilidade de manutenção do sistema.

### **2.1. A Escolha da Distribuição: A Vantagem das *Rolling Release***

O Hyprland é um projeto de desenvolvimento rápido e de vanguarda ("bleeding-edge"), o que significa que ele depende de versões muito recentes de bibliotecas do sistema, como wlroots, mesa e systemd.15 Por essa razão, os desenvolvedores do Hyprland recomendam e testam oficialmente em distribuições de lançamento contínuo (  
*rolling release*), como Arch Linux e Fedora.15 Essas distribuições fornecem um fluxo constante de atualizações de pacotes, garantindo que as dependências do Hyprland estejam sempre atualizadas.  
Tentar instalar o Hyprland em distribuições de lançamento fixo (*fixed release*), especialmente as versões de Suporte de Longo Prazo (LTS) como Ubuntu LTS ou Debian Stable, pode levar a "grandes problemas".15 Os pacotes mais antigos nesses repositórios podem ser incompatíveis com as versões mais recentes do Hyprland, resultando em falhas na compilação, bugs gráficos ou instabilidade geral. Embora seja tecnicamente possível instalar em versões mais recentes e não-LTS do Ubuntu, muitas vezes requer a adição de repositórios de terceiros e uma configuração mais complexa.17  
A escolha da distribuição é, portanto, o primeiro e mais crítico ponto de decisão. Optar por Arch Linux ou Fedora alinha o usuário com o caminho de menor resistência técnica, oferecendo uma experiência mais estável e com melhor suporte da comunidade Hyprland. Para um usuário vindo do GNOME, que funciona bem em quase qualquer distro, essa mudança de mentalidade é fundamental: para o Hyprland, a escolha da distro não é apenas uma preferência, mas uma questão de compatibilidade fundamental.

### **2.2. Guia de Instalação Detalhado**

O processo de instalação varia ligeiramente entre as distribuições recomendadas. É altamente aconselhável criar um backup do sistema com ferramentas como Timeshift ou snapper antes de prosseguir, especialmente se forem utilizados scripts de instalação da comunidade.19

#### **2.2.1. Arch Linux**

O Arch Linux é considerado o ambiente ideal para o Hyprland. Existem duas maneiras principais de instalação:

1. **Versão Estável (Pacote Oficial):** Para a maioria dos usuários, a instalação da versão de lançamento estável através do gerenciador de pacotes pacman é a abordagem recomendada. Isso garante um sistema testado e mais previsível.  
   Bash  
   sudo pacman \-S hyprland

   15  
2. **Versão de Desenvolvimento (AUR):** Para usuários que desejam os recursos mais recentes e não se importam com a possibilidade de instabilidade, a versão \-git pode ser instalada a partir do Arch User Repository (AUR) usando um auxiliar como o yay.  
   Bash  
   yay \-S hyprland-git

   15

Existem também scripts de instalação da comunidade, como o de JaKooLit, que automatizam a instalação do Hyprland e de um conjunto completo de utilitários (Waybar, Rofi, etc.), fornecendo um ponto de partida configurado.19 Embora convenientes, é crucial entender o que esses scripts fazem antes de executá-los.

#### **2.2.2. Fedora**

No Fedora, o Hyprland está disponível nos repositórios oficiais e pode ser instalado com o dnf. Para usuários que desejam compilar plugins, é importante instalar também o pacote de desenvolvimento (hyprland-devel).15

Bash

sudo dnf install hyprland  
sudo dnf install hyprland-devel \# Opcional, para desenvolver plugins

Para obter atualizações mais rápidas, a comunidade mantém um repositório COPR que pode ser adicionado ao sistema.15

#### **2.2.3. Ubuntu e Debian**

A instalação em distribuições baseadas em Debian é mais desafiadora. Para versões recentes como o Ubuntu 24.10, o Hyprland está disponível no repositório universe.15

Bash

sudo add-apt-repository universe  
sudo apt update  
sudo apt install hyprland

Para versões mais antigas ou para obter uma versão mais recente, pode ser necessário adicionar repositórios de terceiros, como o PikaOS, ou compilar a partir do código-fonte, um processo que exige a instalação manual de inúmeras dependências.15 Dada a recomendação oficial contra essas distros, os usuários devem proceder com cautela.16

### **2.3. Primeiros Momentos: Lançando a Sessão e a Configuração Inicial**

Uma vez instalado, o Hyprland não se integra automaticamente ao menu de login como um ambiente de desktop completo. Existem duas formas principais de iniciar uma sessão:

1. **A partir de um Terminal Virtual (TTY):** Esta é a maneira mais direta. Após fazer login em um TTY (geralmente acessível com Ctrl+Alt+F3), basta executar o comando Hyprland.  
   Bash  
   Hyprland

   22  
2. **Através de um Display Manager:** Para uma experiência de login mais tradicional, um Display Manager (DM) como o SDDM ou GDM pode ser usado. O SDDM é frequentemente recomendado por sua boa compatibilidade com o Hyprland.22 Após a instalação do Hyprland, uma nova opção de sessão "Hyprland" deve aparecer no menu do DM na tela de login.19

No primeiro lançamento, o Hyprland criará um arquivo de configuração padrão em \~/.config/hypr/hyprland.conf.22 Este arquivo contém uma configuração básica e serve como ponto de partida. O próximo passo é abrir este arquivo com um editor de texto (como  
vim ou nano a partir de um terminal, que pode ser aberto com o atalho padrão SUPER \+ Enter) e começar a jornada de personalização.

## **Seção 3: Montando o Quebra-Cabeça: Componentes Essenciais para um Ambiente Funcional**

Diferente do GNOME, que fornece um conjunto coeso de ferramentas, o Hyprland requer que o usuário selecione e integre cada componente do seu desktop. Esta seção detalha as peças fundamentais necessárias para construir uma experiência de usuário completa e funcional, transformando o compositor básico em um ambiente de trabalho produtivo. A configuração desses componentes não é isolada; ela é interdependente. A escolha de uma barra de status influencia como os workspaces são exibidos, o que, por sua vez, afeta como eles são configurados no hyprland.conf. Uma aparência coesa exige que as cores, fontes e ícones sejam consistentes em todos esses componentes, promovendo uma abordagem holística de "theming" (tematização).

### **3.1. A Barra de Status com Waybar**

A barra de status é o principal centro de informações do desktop. Waybar é a escolha predominante na comunidade Hyprland por ser altamente personalizável, feita especificamente para compositores baseados em wlroots e ter suporte nativo para o Hyprland.24  
A configuração começa com a instalação do pacote waybar e a cópia dos arquivos de configuração padrão de /etc/xdg/waybar/ para \~/.config/waybar/.24 A personalização é feita através de dois arquivos principais:  
config (um arquivo JSON que define quais módulos são exibidos e sua posição) e style.css (que controla toda a aparência visual, usando a sintaxe CSS).27  
Uma etapa crucial para a integração com o Hyprland é substituir as referências a sway/\* nos módulos por hyprland/\*. Por exemplo, o módulo de workspaces deve ser alterado de sway/workspaces para hyprland/workspaces.24  
Para que a Waybar inicie automaticamente com o Hyprland, a seguinte linha deve ser adicionada ao arquivo \~/.config/hypr/hyprland.conf:

exec-once \= waybar

24

### **3.2. Lançadores de Aplicação com Rofi**

Um lançador de aplicativos é essencial para um fluxo de trabalho rápido e centrado no teclado. Rofi é uma ferramenta extremamente versátil que pode funcionar como um lançador de aplicativos, um alternador de janelas e um substituto para o dmenu.29 Desde 2025, o Rofi tem suporte nativo ao Wayland, tornando-o uma excelente escolha para o Hyprland.29  
A instalação no Arch Linux requer o pacote rofi-wayland.31 A funcionalidade do Rofi é dividida em modos, sendo os mais comuns  
run (executar comandos) e drun (lançar aplicativos a partir de arquivos .desktop).29 A aparência do Rofi é totalmente personalizável através de arquivos de tema com a extensão  
.rasi, que usam uma sintaxe semelhante ao CSS.31  
Um atalho comum para lançar o Rofi é SUPER \+ D, configurado no hyprland.conf da seguinte forma:

bind \= SUPER, D, exec, rofi \-show drun

22

### **3.3. Notificações com Mako**

Aplicações precisam de uma forma de comunicar eventos ao usuário. No Hyprland, isso é feito por um daemon de notificação. Mako é uma opção leve, nativa do Wayland e altamente recomendada.27 Uma de suas grandes vantagens é que ele não precisa ser iniciado manualmente; ele é ativado via D-Bus na primeira vez que uma aplicação envia uma notificação.33  
A configuração do Mako é feita através do arquivo \~/.config/mako/config. Nele, é possível personalizar a aparência, a posição na tela, as cores, as fontes e o tempo de exibição das notificações. É possível até mesmo definir estilos diferentes com base no nível de urgência da notificação (baixo, normal, crítico).33  
dunst e swaync são outras alternativas populares, com dunst sendo conhecido por sua simplicidade e swaync por oferecer um centro de notificações mais completo.34

### **3.4. Gerenciamento de Papel de Parede com swww**

O papel de parede é um elemento central da estética do desktop. Embora o Hyprland tenha sua própria ferramenta, hyprpaper, a comunidade frequentemente prefere swww (A Solution to your Wayland Wallpaper Woes).36 As vantagens do  
swww incluem sua eficiência, a capacidade de exibir papéis de parede animados (GIFs) e, crucialmente, a habilidade de alterar o papel de parede em tempo de execução sem reiniciar o daemon.37  
O uso envolve duas etapas: primeiro, iniciar o daemon em segundo plano, o que deve ser feito uma única vez por sessão através do hyprland.conf:

exec-once \= swww-daemon

39  
Depois, para definir um papel de parede, usa-se o comando cliente swww img. O swww também oferece efeitos de transição suaves ao mudar de imagem, alinhando-se bem com a estética focada em animações do Hyprland.37

Bash

swww img /caminho/para/seu/wallpaper.png \--transition-type wipe

### **3.5. Capturas de Tela com grim e slurp**

A capacidade de tirar capturas de tela é uma funcionalidade básica. No ecossistema wlroots, a combinação padrão é grim e slurp.40  
grim é a ferramenta que efetivamente captura a imagem da tela, enquanto slurp é um utilitário que permite selecionar uma região da tela com o mouse.42  
Para um fluxo de trabalho eficiente, esses comandos são geralmente associados a atalhos de teclado no hyprland.conf. Por exemplo:

\# Captura a tela inteira e salva em um arquivo  
bind \= , Print, exec, grim \~/Pictures/$(date \+'%Y-%m-%d\_%H-%M-%S').png

\# Seleciona uma região e copia para a área de transferência  
bind \= SHIFT, Print, exec, grim \-g "$(slurp)" \- | wl-copy

42  
Este último exemplo demonstra a modularidade do sistema: a saída de grim é redirecionada (|) para wl-copy (do pacote wl-clipboard), que a coloca na área de transferência em vez de salvá-la em um arquivo.42

### **3.6. Componentes Indispensáveis ("Must-haves")**

Além dos utilitários visíveis, um ambiente Hyprland funcional depende de vários serviços de segundo plano que o GNOME gerencia de forma transparente. É crucial garantir que os seguintes componentes estejam instalados e funcionando 43:

* **PipeWire e WirePlumber:** O framework moderno para áudio e vídeo no Linux. É absolutamente essencial para o compartilhamento de tela funcionar.  
* **XDG Desktop Portal:** Um framework que permite que aplicativos (especialmente os em sandbox como Flatpaks) solicitem ações do sistema, como abrir arquivos ou compartilhar a tela. O pacote xdg-desktop-portal-hyprland é a implementação específica para o Hyprland.  
* **Agente de Autenticação:** Um programa que exibe a caixa de diálogo de senha quando um aplicativo precisa de privilégios de administrador (Polkit). hyprpolkitagent é uma opção leve para isso.  
* **Suporte a Qt Wayland:** Os pacotes qt5-wayland e qt6-wayland são necessários para que aplicativos baseados em Qt rodem nativamente no Wayland, evitando problemas de compatibilidade e escalonamento.  
* **Fontes:** Um conjunto básico de fontes, como noto-fonts, é necessário para renderizar texto. Para ícones em barras de status e outros locais, a instalação de uma "Nerd Font" é altamente recomendada.

A tabela a seguir oferece um resumo das escolhas para cada categoria de componente:

| Categoria | Recomendação Principal | Alternativas Notáveis | Principais Características |
| :---- | :---- | :---- | :---- |
| **Barra de Status** | Waybar | AGS, Eww | Altamente configurável via CSS; suporte nativo a Hyprland. |
| **Lançador de Apps** | Rofi | wofi, fuzzel, tofi | Versátil (app, janela, script); temas via .rasi. |
| **Notificações** | Mako | dunst, swaync | Leve; ativado por D-Bus; configurável por urgência. |
| **Papel de Parede** | swww | hyprpaper, swaybg | Eficiente; suporta GIFs e transições animadas. |
| **Captura de Tela** | grim \+ slurp | grimblast, flameshot | Padrão wlroots; modular; integra-se com wl-copy. |

## **Seção 4: O Coração do Sistema: Dominando o hyprland.conf**

O arquivo hyprland.conf é o centro nevrálgico de todo o ambiente. É aqui que o comportamento do compositor, a aparência das janelas e, mais importante, o fluxo de trabalho do usuário são definidos. Dominar este arquivo é a chave para desbloquear todo o potencial do Hyprland. A abordagem de ter um único arquivo de texto para toda a configuração transforma a gestão do desktop em uma prática de "Configuração como Código" (Configuration as Code). Diferente do GNOME, onde as configurações estão espalhadas, aqui todo o "estado" do ambiente pode ser capturado, versionado com Git e replicado em qualquer máquina, elevando a personalização a uma forma de engenharia de sistemas pessoais.

### **4.1. Anatomia do Arquivo de Configuração**

O arquivo de configuração principal está localizado em \~/.config/hypr/hyprland.conf.44 Sua sintaxe é simples e consiste em palavras-chave seguidas por um sinal de igual e um valor (  
keyword \= value).46 Uma das características mais poderosas do Hyprland é o recarregamento automático da configuração: basta salvar o arquivo e as alterações são aplicadas instantaneamente, sem a necessidade de reiniciar a sessão.11  
Para manter a organização, especialmente em configurações complexas, o Hyprland suporta a diretiva source=. Isso permite dividir a configuração em múltiplos arquivos (por exemplo, keybinds.conf, windowrules.conf, theme.conf) e incluí-los no arquivo principal, tornando o projeto mais modular e fácil de gerenciar.46

\# Exemplo de inclusão de arquivos no hyprland.conf  
source \= \~/.config/hypr/themes/color.conf  
source \= \~/.config/hypr/configs/Keybinds.conf

### **4.2. binds: Criando um Fluxo de Trabalho Centrado no Teclado**

A seção de atalhos de teclado (binds) é onde o fluxo de trabalho do usuário ganha vida. A eficiência em um gerenciador de janelas em mosaico vem da capacidade de controlar quase tudo sem tocar no mouse. A sintaxe para definir um atalho é bind \= MOD, key, dispatcher, params.22

* MOD: A tecla modificadora, como SUPER (tecla Windows), ALT, CTRL, SHIFT. É comum definir uma variável para a tecla principal, como $mainMod \= SUPER.  
* key: A tecla a ser pressionada, como D, Q, Return (Enter).  
* dispatcher: A ação a ser executada, como exec (executar um comando), killactive (fechar a janela ativa), workspace (mudar de área de trabalho).  
* params: Argumentos para o dispatcher, como o comando a ser executado ou o número do workspace.

Aqui estão alguns atalhos essenciais que formam a base de qualquer configuração:

\# Define a tecla SUPER como o modificador principal  
$mainMod \= SUPER

\# Lançar aplicações  
bind \= $mainMod, Return, exec, kitty          \# Lança o terminal (kitty)  
bind \= $mainMod, D, exec, rofi \-show drun      \# Lança o Rofi

\# Gerenciamento de janelas  
bind \= $mainMod, Q, killactive,                \# Fecha a janela ativa  
bind \= $mainMod, F, fullscreen,               \# Alterna para tela cheia

\# Mover o foco entre janelas  
bind \= $mainMod, left, movefocus, l  
bind \= $mainMod, right, movefocus, r  
bind \= $mainMod, up, movefocus, u  
bind \= $mainMod, down, movefocus, d

\# Mudar para workspaces  
bind \= $mainMod, 1, workspace, 1  
bind \= $mainMod, 2, workspace, 2  
\#... e assim por diante

\# Mover a janela ativa para um workspace  
bind \= $mainMod SHIFT, 1, movetoworkspace, 1  
bind \= $mainMod SHIFT, 2, movetoworkspace, 2  
\#... e assim por diante

22

### **4.3. windowrule: Automatizando o Comportamento das Aplicações**

As regras de janela (windowrule) permitem definir comportamentos específicos para aplicações com base em suas propriedades, como classe ou título. Isso é fundamental para criar um ambiente organizado e previsível.45 A sintaxe é  
windowrule \= rule, parameters.49  
Para descobrir a classe e o título de uma janela, pode-se usar o comando hyprctl clients em um terminal. Com essas informações, é possível criar regras poderosas.  
Exemplos práticos:

\# Fazer o gerenciador de arquivos (Thunar) flutuar  
windowrule \= float, class:^(Thunar)$

\# Abrir o Spotify sempre no workspace 9  
windowrule \= workspace 9, class:^(spotify)$

\# Definir uma opacidade específica para o terminal Kitty  
windowrule \= opacity 0.9, class:^(kitty)$

\# Fazer com que a janela do seletor de arquivos do Firefox flutue no centro  
windowrule \= float, class:^(firefox)$, title:^(Abrir arquivo)$  
windowrule \= center, class:^(firefox)$, title:^(Abrir arquivo)$

49  
As regras são avaliadas de cima para baixo, então a ordem em que são escritas no arquivo de configuração é importante.49

### **4.4. Configuração de Múltiplos Monitores**

Configurar múltiplos monitores no Hyprland é um processo direto. Primeiro, é necessário identificar os nomes dos monitores conectados com o comando hyprctl monitors.45 A saída fornecerá nomes como  
DP-1, HDMI-A-1, etc.  
Em seguida, no hyprland.conf, a diretiva monitor é usada para configurar cada tela. A sintaxe é monitor \= name, resolution, position, scale.52

* name: O nome do monitor (ex: DP-1).  
* resolution: A resolução e a taxa de atualização (ex: 1920x1080@144). preferred pode ser usado para detecção automática.  
* position: A posição do monitor no layout virtual (ex: 0x0 para o monitor principal, 1920x0 para um segundo monitor à direita do principal).  
* scale: O fator de escala (ex: 1 para 100%, 1.5 para 150%).

Exemplo para uma configuração de dois monitores:

\# Monitor principal (laptop)  
monitor=eDP-1, 1920x1080@144, 0x0, 1

\# Monitor externo à direita do principal  
monitor=DP-1, 2560x1440@120, 1920x0, 1

12  
Também é possível associar workspaces a monitores específicos:

workspace=1, monitor:eDP-1  
workspace=6, monitor:DP-1

54

### **4.5. O "Eyecandy": Animações, Desfoque e Aparência**

Um dos maiores diferenciais do Hyprland é sua capacidade de produzir efeitos visuais impressionantes com ótimo desempenho.11 Essas configurações são controladas principalmente nas seções  
animations {} e decoration {}.  
Na seção decoration {}, pode-se configurar:

* rounding: Bordas arredondadas para as janelas.  
* blur: Efeito de desfoque para janelas transparentes.  
* drop\_shadow: Sombras projetadas pelas janelas.  
* active\_opacity e inactive\_opacity: Níveis de transparência para janelas ativas e inativas.

Na seção animations {}, pode-se habilitar e personalizar as animações:

* enabled \= true: Ativa o sistema de animações.  
* bezier \= name, p1, p2, p3, p4: Define uma curva de Bézier personalizada para controlar a aceleração e desaceleração das animações.  
* animation \= name, on, speed, curve, style: Configura uma animação específica (ex: windowsIn, workspaces, fade).

Exemplo de configuração visual:

decoration {  
    rounding \= 10  
    blur {  
        enabled \= true  
        size \= 5  
        passes \= 2  
    }  
    drop\_shadow \= yes  
    shadow\_range \= 4  
    shadow\_render\_power \= 3  
    col.shadow \= rgba(1a1a1aee)  
}

animations {  
    enabled \= yes  
    bezier \= myBezier, 0.05, 0.9, 0.1, 1.05  
    animation \= windows, 1, 7, myBezier  
    animation \= windowsOut, 1, 7, default, popin 80%  
    animation \= workspaces, 1, 6, default, slide  
}

13  
Essas opções permitem que o usuário ajuste finamente o equilíbrio entre estética e desempenho, criando uma experiência visual única.

## **Seção 5: A Arte do "Ricing": Criando uma Estética Coesa e Pessoal**

"Ricing" é o termo usado na comunidade Linux para o processo de personalização profunda da aparência de um ambiente de desktop. No Hyprland, onde o sistema é construído a partir de componentes modulares, alcançar uma estética coesa é um desafio e uma forma de arte. Isso envolve orquestrar múltiplos sistemas de theming que não foram projetados para interoperar nativamente. O sucesso no "ricing" não se trata apenas de escolher temas, mas de entender e gerenciar a configuração de UI de cada componente, transformando o usuário em um verdadeiro "gerente de tema" para todo o seu desktop.

### **5.1. Unificando a Aparência: Aplicando Temas GTK**

Muitas aplicações de desktop populares, como gerenciadores de arquivos (Thunar, Nautilus), editores de texto e navegadores, usam o toolkit GTK. Para que essas aplicações não pareçam deslocadas, é essencial aplicar um tema GTK que harmonize com o resto do sistema.56  
O processo envolve várias etapas:

1. **Instalação de Temas:** Os temas GTK podem ser instalados através do gerenciador de pacotes da distribuição ou baixados de sites como o GNOME-Look e colocados nos diretórios \~/.themes ou /usr/share/themes.57  
2. **Aplicação do Tema:** Ferramentas com interface gráfica como nwg-look ou lxappearance podem ser usadas para visualizar e aplicar temas GTK, temas de ícones e configurações de fontes.56  
3. **Configuração por Variáveis de Ambiente:** Para garantir que os temas sejam carregados corretamente pelo Hyprland em cada inicialização, é a melhor prática definir variáveis de ambiente no hyprland.conf. Isso informa a todas as aplicações GTK qual tema, ícones e fontes usar.57

Exemplo de configuração de ambiente no hyprland.conf:

\# Configuração de temas GTK  
env \= GTK\_THEME,Catppuccin-Mocha-Standard-Blue-Dark  
exec-once \= gsettings set org.gnome.desktop.interface gtk-theme 'Catppuccin-Mocha-Standard-Blue-Dark'  
exec-once \= gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'

60  
Para aplicações que usam libadwaita (o mais recente toolkit do GNOME), pode ser necessário definir o esquema de cores preferido (claro ou escuro) separadamente:

exec-once \= gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

60

### **5.2. Personalizando Ícones e Cursores**

A consistência visual se estende aos ícones de aplicativos e ao cursor do mouse. Pacotes de ícones como Papirus ou Tela podem ser instalados e aplicados da mesma forma que os temas GTK, através de ferramentas como nwg-look e gsettings.61  
Para o cursor, o Hyprland introduziu um novo formato eficiente chamado hyprcursor.63 No entanto, muitas aplicações (especialmente as baseadas em GTK e XWayland) ainda dependem do formato legado  
XCursor. Portanto, uma configuração robusta requer a configuração de ambos:

1. **Instalar Temas de Cursor:** Instale um tema que forneça tanto a versão hyprcursor quanto a XCursor (ex: Bibata-Modern-Ice). Os temas devem ser colocados em \~/.icons ou \~/.local/share/icons.63  
2. **Configurar Hyprcursor:** Defina o tema e o tamanho no hyprland.conf usando variáveis de ambiente HYPRCURSOR\_\*.  
3. **Configurar XCursor:** Defina as variáveis XCURSOR\_\* para aplicações legadas e use gsettings para aplicações GTK.

Exemplo de configuração completa para cursores no hyprland.conf:

\# Configuração do Hyprcursor (nativo)  
env \= HYPRCURSOR\_THEME,Bibata-Modern-Ice  
env \= HYPRCURSOR\_SIZE,24

\# Configuração de fallback para XCursor (aplicações legadas)  
env \= XCURSOR\_THEME,Bibata-Modern-Ice  
env \= XCURSOR\_SIZE,24

\# Aplica o tema de cursor para aplicações GTK  
exec-once \= gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'

63

### **5.3. A Importância da Tipografia**

Uma tipografia consistente é a base de uma interface de usuário legível e esteticamente agradável. A escolha da fonte afeta tudo, desde o terminal até a barra de status e as aplicações. É altamente recomendável instalar uma "Nerd Font", como JetBrainsMono Nerd Font ou FiraCode Nerd Font. Essas fontes são "patched" para incluir milhares de ícones (glyphs) de conjuntos como Font Awesome, Material Design Icons, etc. Esses ícones são essenciais para exibir símbolos em utilitários como a Waybar.62  
As fontes devem ser definidas em cada componente:

* **Hyprland:** Para mensagens do sistema, pode-se definir uma fonte global.66  
* **Terminal (ex: Kitty):** A fonte é definida no arquivo de configuração do terminal (\~/.config/kitty/kitty.conf).  
* **Waybar:** A família de fontes é definida no arquivo style.css da Waybar.  
* **Aplicações GTK:** A fonte padrão é definida via nwg-look ou gsettings.

### **5.4. Explorando "Dotfiles": Inspiração e Implementação**

A maneira mais eficaz de aprender "ricing" e construir um ambiente coeso é estudar as configurações de outros usuários. O GitHub é um vasto repositório de hyprland-dotfiles, que são coleções de arquivos de configuração que outros usuários compartilham.6  
Explorar esses repositórios oferece uma visão inestimável de como os especialistas integram todos os componentes. Repositórios populares como os de end-4 (focado em uma experiência altamente integrada com widgets personalizados), mylinuxforwork (um ambiente completo e rico em recursos com scripts de instalação) e JaKooLit (oferece scripts para várias distribuições e temas) são excelentes pontos de partida.7  
A abordagem recomendada não é simplesmente copiar e colar, mas sim "dissecar" esses dotfiles:

1. **Clonar o Repositório:** Baixe os arquivos para sua máquina local.  
2. **Analisar a Estrutura:** Observe como os arquivos estão organizados. Geralmente, eles estão dentro de um diretório .config.  
3. **Ler o hyprland.conf:** Entenda como o usuário principal estrutura sua configuração, quais scripts ele executa (exec-once) e como ele define seus atalhos.  
4. **Estudar as Configurações dos Componentes:** Abra os arquivos de configuração da Waybar, Rofi, kitty, etc., para ver como o tema é aplicado de forma consistente em todos eles.  
5. **Adaptar e Adotar:** Pegue as partes que você gosta e adapte-as à sua própria configuração. Este processo de aprendizado iterativo é a essência do "ricing".69

## **Seção 6: Otimizando a Produtividade: Desenhando Seu Workflow Pessoal**

O objetivo final da transição para o Hyprland é a criação de um fluxo de trabalho (workflow) que seja mais eficiente, pessoal e ergonômico do que o oferecido por um ambiente de desktop tradicional. No Hyprland, o workflow não é algo imposto pela interface; é um "contrato" que o usuário estabelece consigo mesmo e codifica no hyprland.conf. A produtividade é o resultado de um processo deliberado de autoanálise (Como eu trabalho?), design (Qual é a melhor organização para minhas tarefas?) e implementação (Codificar essas regras e atalhos).

### **6.1. Dominando o Tiling Dinâmico**

O gerenciamento de janelas em mosaico (tiling) é a característica central do Hyprland. Em vez de janelas flutuantes que se sobrepõem e exigem gerenciamento manual, o tiling organiza as janelas automaticamente em uma grade que preenche a tela, eliminando espaço desperdiçado.4 O Hyprland é "dinâmico" porque ajusta o layout automaticamente à medida que novas janelas são abertas.13  
Os dois layouts principais são:

* **Dwindle:** O layout padrão, que divide a tela em um padrão de espiral. Cada nova janela divide o espaço da janela atual.55  
* **Master:** Um layout mais tradicional em tiling WMs, que mantém uma janela principal ("master") em uma área maior (geralmente à esquerda) e empilha as outras janelas em uma área secundária.55

O usuário pode alternar entre layouts com um atalho de teclado e usar outros atalhos para redimensionar as divisões (resizeactive) ou reorganizar as janelas (swapwindow).  
Apesar de ser um tiling WM, o Hyprland suporta totalmente janelas flutuantes. Com um atalho (bind \= $mainMod, SPACE, togglefloating), qualquer janela pode ser alternada para o modo flutuante, permitindo que seja movida e redimensionada livremente com o mouse (segurando a tecla SUPER).70 Isso é útil para aplicações que não se encaixam bem em um layout de mosaico, como calculadoras ou caixas de diálogo.

### **6.2. Workspaces ao Seu Dispor**

Workspaces (áreas de trabalho virtuais) são a espinha dorsal da organização no Hyprland. Em vez de minimizar janelas ou empilhá-las, o fluxo de trabalho incentiva a distribuição de tarefas em workspaces dedicados.4 O Hyprland oferece uma flexibilidade imensa na gestão de workspaces:

* **Workspaces Numéricos:** A configuração padrão usa workspaces numerados de 1 a 10, acessíveis com SUPER \+ \[número\]. Eles são criados dinamicamente quando necessários.  
* **Workspaces Nomeados:** Para uma organização mais semântica, é possível criar workspaces com nomes específicos. Isso ajuda a associar um workspace a uma tarefa ou projeto.72  
  \# Atribui o nome 'WWW' ao workspace 2  
  workspace \= 2, name:WWW

  \# Atalho para ir para um workspace pelo nome  
  bind \= $mainMod, W, workspace, name:WWW

* **Workspaces Especiais (Scratchpads):** Um workspace especial é um tipo de "scratchpad" que pode ser invocado para aparecer sobre qualquer workspace atual, sem mudar o foco principal. É ideal para aplicações de acesso rápido, como um terminal, um player de música ou um bloco de notas.11  
  \# Move a janela focada para o workspace especial 'music'  
  bind \= $mainMod SHIFT, S, movetoworkspace, special:music

  \# Alterna a visibilidade do workspace especial 'music'  
  bind \= $mainMod, S, togglespecialworkspace, music

  13

### **6.3. Exemplos de Workflow na Prática**

Combinando tiling, workspaces e regras de janela, é possível construir fluxos de trabalho altamente eficientes para diferentes cenários.

#### **6.3.1. Workflow de Desenvolvimento de Software**

Um desenvolvedor pode organizar seu ambiente da seguinte forma 71:

* **Workspace 1 (name:CODE):** Editor de código (VS Code ou Neovim) ocupando a maior parte da tela. Uma janela de terminal menor ao lado para executar comandos.  
  * windowrule \= workspace name:CODE, class:^(Code)$  
* **Workspace 2 (name:BROWSER):** Navegador web aberto com documentação, Stack Overflow ou a aplicação sendo desenvolvida.  
* **Workspace 3 (name:DB):** Ferramentas de banco de dados ou outros serviços relacionados.  
* **Workspace Especial (name:TERM):** Um terminal flutuante de acesso rápido, invocado com SUPER \+ T, para tarefas rápidas sem sair do contexto atual.  
* **Workspace Especial (name:CHAT):** Cliente de comunicação da equipe (Slack/Discord) em um scratchpad, para verificar mensagens sem interromper o fluxo de codificação.

#### **6.3.2. Workflow de Comunicação e Mídia**

Para tarefas gerais, um usuário pode usar uma abordagem baseada em aplicações 71:

* **Workspace 1:** Navegador web para uso geral.  
* **Workspace 2:** Cliente de e-mail e calendário.  
* **Workspace Especial (name:MUSIC):** Spotify ou outro player de música, controlado por um scratchpad.  
  * exec-once \= spotify  
  * windowrule \= workspace special:MUSIC, class:^(spotify)$  
* **Workspace Especial (name:SOCIAL):** Discord, Telegram ou outro cliente de chat.

Essa abordagem, onde o usuário codifica suas intenções e hábitos em regras e atalhos, é o que torna a experiência do Hyprland tão poderosa. A eficiência não é um recurso do software, mas o resultado de um design de sistema pessoal e deliberado.

## **Seção 7: Análise Comparativa: Vantagens e Desafios da Migração**

A decisão de migrar do GNOME para o Hyprland envolve uma análise cuidadosa das vantagens e desvantagens de cada ambiente, especialmente em áreas como desempenho, personalização e usabilidade. A percepção comum de que gerenciadores de janelas são universalmente "mais leves" que ambientes de desktop é uma simplificação que merece um exame mais detalhado.

### **7.1. Desempenho no Mundo Real: RAM, CPU e Jogos**

As métricas de desempenho são frequentemente um fator decisivo para os usuários que consideram essa mudança.

* **Uso de RAM:** Em estado ocioso, o Hyprland é consistentemente mais leve que o GNOME. Configurações mínimas do Hyprland podem consumir entre 500 MB e 900 MB de RAM, enquanto o GNOME normalmente inicia com um consumo de 1.5 GB a mais de 2 GB.1 Essa diferença se deve ao fato de que o GNOME carrega um grande número de serviços e daemons em segundo plano para fornecer sua experiência integrada, enquanto o Hyprland carrega apenas o compositor e os componentes que o usuário explicitamente adicionou.1  
* **Uso de CPU:** A situação do uso da CPU é mais complexa. Embora em idle o Hyprland seja muito eficiente, o uso de seus recursos de "eyecandy" (desfoque, animações complexas, sombras) pode levar a um consumo de CPU/GPU mais alto sob carga do que o GNOME, especialmente em hardware mais antigo.78 Alguns usuários relatam temperaturas de CPU significativamente mais altas ao assistir a vídeos no Hyprland em comparação com o GNOME, sugerindo que o pipeline de renderização para certas tarefas pode ser mais intensivo.78 A "leveza" do Hyprland está em sua modularidade e baixo consumo de RAM em repouso, mas seu desempenho sob carga é uma variável que o próprio usuário controla através do  
  hyprland.conf. Desativar os efeitos visuais pode torná-lo extremamente performático.41  
* **Desempenho em Jogos:** Os resultados para jogos são mistos e muitas vezes dependem do hardware específico (especialmente da GPU) e da configuração. Alguns usuários relatam um aumento drástico de FPS e uma experiência mais suave no Hyprland, atribuindo isso à menor sobrecarga do compositor.1 Outros, no entanto, não observam diferenças significativas ou até preferem a estabilidade e a implementação madura de Wayland e VRR (Variable Refresh Rate) do GNOME, que é considerada uma das melhores no mundo Linux.1 Para usuários com GPUs NVIDIA, a experiência pode ser mais instável no Hyprland, o que pode impactar negativamente o desempenho em jogos.14

### **7.2. Liberdade vs. Conveniência: O Espectro da Personalização**

Este é o trade-off central da migração.

* **GNOME:** Oferece uma experiência "pronta para uso" com alta conveniência. A personalização existe, mas é limitada ao que o ecossistema de extensões permite.3 A vantagem é que o usuário pode ser produtivo em minutos após a instalação, sem precisar se preocupar com a configuração de componentes básicos.2 A desvantagem é a falta de controle granular e a filosofia de design opinativa que pode não agradar a todos.1  
* **Hyprland:** Oferece liberdade quase total. Cada aspecto do ambiente, desde o comportamento do clique do mouse até a curva de animação de uma janela, pode ser ajustado.11 A desvantagem é que essa liberdade vem com a responsabilidade de construir tudo do zero. Para um usuário que não tem tempo ou interesse em configurar minuciosamente seu sistema, essa tarefa pode parecer esmagadora e desmotivadora.2

A escolha entre os dois depende do que o usuário valoriza mais: o tempo economizado com uma configuração pronta ou o controle obtido através de uma personalização profunda.

### **7.3. Navegando a Curva de Aprendizagem**

O GNOME é projetado para ser intuitivo, com uma curva de aprendizado quase nula para usuários familiarizados com desktops modernos. Sua interface gráfica e configurações centralizadas tornam-no acessível a todos os níveis de habilidade.79  
O Hyprland, por outro lado, tem uma curva de aprendizado acentuada e inevitável.8 Ele exige que o usuário:

* Se sinta confortável trabalhando na linha de comando.  
* Esteja disposto a ler a documentação (a Wiki do Hyprland é excelente, mas densa).  
* Aprenda a sintaxe de arquivos de configuração para múltiplos programas.  
* Entenda a relação entre os diferentes componentes do sistema (compositor, barra, portal, etc.).

No entanto, essa curva de aprendizado pode ser vista como um investimento. Ao superá-la, o usuário não apenas obtém um desktop personalizado, mas também um conhecimento muito mais profundo sobre como o ambiente gráfico do Linux funciona. A longo prazo, a eficiência ganha com um fluxo de trabalho centrado no teclado e totalmente otimizado pode superar em muito o tempo inicial gasto na configuração.

## **Seção 8: Guia de Solução de Problemas e Tópicos Avançados**

A jornada com o Hyprland, especialmente para quem vem de um ambiente mais controlado como o GNOME, invariavelmente envolve a resolução de problemas técnicos. Usar o Hyprland força o usuário a confrontar o estado atual do ecossistema Linux, expondo quais partes são "modernas" (nativas de Wayland, cientes do PipeWire) e quais são "legadas" (dependentes do X11, drivers NVIDIA com implementações incompletas). Superar esses desafios é um curso intensivo sobre a arquitetura moderna do desktop Linux.

### **8.1. O Desafio da NVIDIA**

O uso de GPUs NVIDIA com drivers proprietários em compositores Wayland, incluindo o Hyprland, é historicamente uma fonte de problemas. Embora a situação tenha melhorado significativamente, a configuração ainda requer etapas específicas e a experiência pode ser menos estável do que com GPUs AMD ou Intel.12  
Os passos essenciais para uma configuração funcional incluem:

1. **Instalação dos Drivers Corretos:** É crucial instalar o pacote nvidia-dkms (para compatibilidade com diferentes versões de kernel) e os cabeçalhos do kernel correspondentes (linux-headers).81  
2. **Configuração do Kernel e Initramfs:** O DRM (Direct Rendering Manager) Kernel Mode Setting (KMS) deve ser ativado. Isso é feito adicionando nvidia\_drm.modeset=1 aos parâmetros de inicialização do kernel (via GRUB ou systemd-boot) e incluindo os módulos nvidia, nvidia\_modeset, nvidia\_uvm e nvidia\_drm no mkinitcpio.conf (no Arch Linux) antes de regenerar o initramfs.81  
3. **Variáveis de Ambiente:** Diversas variáveis de ambiente devem ser definidas no hyprland.conf para instruir o sistema a usar os drivers e backends corretos.  
   env \= LIBVA\_DRIVER\_NAME,nvidia  
   env \= \_\_GLX\_VENDOR\_LIBRARY\_NAME,nvidia  
   env \= GBM\_BACKEND,nvidia-drm  
   env \= WLR\_NO\_HARDWARE\_CURSORS,1

   81

**Problemas Comuns e Soluções:**

* **Flickering em Aplicações Electron/XWayland:** Este é um problema clássico causado pela falta de sincronização explícita em versões mais antigas do driver. A solução é forçar essas aplicações a rodar em modo Wayland nativo (ver Seção 8.3) ou usar versões mais recentes do driver NVIDIA (série 555+) e do xorg-xwayland-git que implementam a sincronização explícita.82  
* **Problemas de Suspensão/Hibernação:** Habilitar os serviços nvidia-suspend.service, nvidia-hibernate.service e nvidia-resume.service pode resolver problemas onde o sistema não retorna corretamente do estado de suspensão.81

### **8.2. Compartilhamento de Tela Desmistificado**

O compartilhamento de tela no Wayland é mais seguro que no X11, mas também mais complexo de configurar. Ele depende de uma pilha de software que deve funcionar em conjunto 85:

1. **PipeWire e WirePlumber:** Devem estar instalados e em execução.  
2. **XDG Desktop Portal:** O pacote xdg-desktop-portal-hyprland deve ser instalado. Ele atua como um intermediário, permitindo que as aplicações solicitem um stream de vídeo da tela ao compositor de forma segura.86

**Solucionando Problemas com Aplicações Específicas:**

* **OBS Studio:** Geralmente funciona bem com a fonte "Captura de Tela (PipeWire)" após a configuração correta da pilha acima.86  
* **Navegadores (Chrome, Firefox):** Devem ser executados em modo Wayland nativo para que o compartilhamento de tela funcione. Para o Firefox, isso pode exigir a variável MOZ\_ENABLE\_WAYLAND=1. Para navegadores baseados em Chromium, as flags \--ozone-platform-hint=auto são necessárias.86  
* **Discord:** Este é o caso mais problemático. A aplicação oficial do Discord é baseada em uma versão antiga do Electron e depende do XWayland, que não permite o compartilhamento de tela inteira no Wayland.87 As soluções são:  
  * **Usar o Discord no Navegador:** A forma mais confiável de compartilhar a tela.88  
  * **Usar Vesktop ou Webcord:** Clientes de terceiros que usam uma versão mais recente do Electron com melhor suporte a Wayland.88  
  * **Usar discord-canary:** A versão de testes do Discord, que frequentemente inclui suporte experimental e funcional para compartilhamento de tela no Wayland.88  
  * **Usar xwaylandvideobridge:** Uma solução alternativa que cria uma "ponte" para permitir que aplicações XWayland capturem a tela, embora possa introduzir seus próprios problemas de desempenho.87

### **8.3. Lidando com o Legado: Compatibilidade com XWayland**

O XWayland é uma camada de compatibilidade que permite que aplicações projetadas para o X11 rodem em um ambiente Wayland. Embora seja crucial para a transição, ele pode introduzir alguns problemas.91

* **Renderização Borrada (Pixelada):** O problema mais comum. O XWayland não suporta escalonamento fracionário de forma nativa. Se um monitor está configurado com uma escala de 1.5 (150%), por exemplo, as aplicações Wayland nativas renderizarão perfeitamente, mas as aplicações XWayland serão renderizadas em escala 1x e depois ampliadas ("upscaled") pelo compositor, resultando em uma aparência borrada ou pixelada.40

**Soluções:**

1. **Forçar o Modo Wayland Nativo:** A melhor solução é fazer com que a aplicação rode nativamente em Wayland, se possível. Para aplicações baseadas em Electron (como VS Code, Obsidian, Discord), isso pode ser alcançado definindo a seguinte variável de ambiente no hyprland.conf:  
   env \= ELECTRON\_OZONE\_PLATFORM\_HINT,wayland

   92  
2. **Usar Escala Inteira:** Se uma aplicação crítica não tiver suporte a Wayland, uma solução alternativa é usar fatores de escala inteiros (como 1 ou 2\) nos monitores.  
3. **Ajustes Específicos da Aplicação:** Algumas aplicações têm suas próprias flags para forçar o backend Wayland, que devem ser investigadas na documentação ou em wikis da comunidade.

Aprender a identificar se uma aplicação está rodando via XWayland (usando hyprctl clients e procurando por xwayland: 1\) e saber como forçá-la para o modo Wayland é uma habilidade essencial para qualquer usuário do Hyprland.

## **Seção 9: Conclusão: Sua Jornada com o Hyprland Apenas Começou**

A transição do GNOME para o Hyprland é uma jornada transformadora que vai muito além da simples troca de software. É uma mudança fundamental na relação do usuário com seu computador, evoluindo de um papel de operador passivo para o de arquiteto ativo do seu próprio ambiente digital. Este guia forneceu os fundamentos conceituais, as instruções práticas e as soluções para os desafios comuns encontrados nesse caminho, mas representa apenas o ponto de partida.

### **9.1. Recapitulação: De Usuário a Arquiteto**

Ao longo deste relatório, a jornada foi delineada em etapas progressivas. Começou com a deconstrução da filosofia de um ambiente de desktop integrado, contrastando-o com a abordagem modular e fundamental do Hyprland. Passou pela instalação e pelos primeiros passos, enfatizando a importância de uma base sólida em uma distribuição *rolling-release*. Em seguida, detalhou a montagem do quebra-cabeça, peça por peça, selecionando e configurando componentes essenciais como a barra de status, o lançador de aplicativos e o sistema de notificações para construir um desktop funcional.  
O coração do sistema, o arquivo hyprland.conf, foi explorado em profundidade, demonstrando como atalhos de teclado, regras de janela e configurações visuais são os verdadeiros blocos de construção de um fluxo de trabalho pessoal e eficiente. A arte do "ricing" foi apresentada não como um mero exercício estético, mas como a busca por uma experiência de usuário coesa e unificada. Finalmente, o guia abordou os desafios mais complexos, como a configuração de hardware NVIDIA e a navegação pelas complexidades do compartilhamento de tela e do XWayland, transformando obstáculos em oportunidades de aprendizado sobre a arquitetura moderna do desktop Linux.  
O resultado desse processo não é apenas um desktop que "parece legal", mas um sistema que reflete as necessidades e os hábitos do seu criador, onde cada componente e cada atalho de teclado foi escolhido e posicionado com um propósito.

### **9.2. Próximos Passos: Plugins e a Comunidade**

A personalização com o Hyprland não termina com o hyprland.conf. O próximo nível de customização reside no seu poderoso sistema de plugins.11 Plugins podem adicionar funcionalidades inteiramente novas, como layouts de tiling alternativos, visões gerais de workspaces no estilo do GNOME, ou integrações complexas com outros serviços. A comunidade está constantemente desenvolvendo novos plugins, e para aqueles com conhecimento em C++, é possível criar os seus próprios, estendendo as capacidades do compositor de maneiras que os desenvolvedores originais talvez não tenham previsto.  
A jornada com o Hyprland é, em sua essência, uma jornada contínua de aprendizado e refinamento. A verdadeira força do ecossistema não está apenas no software, mas na comunidade vibrante que o rodeia. Fóruns como o subreddit r/hyprland, servidores no Discord e os inúmeros repositórios de dotfiles no GitHub são recursos inestimáveis para encontrar inspiração, obter ajuda e compartilhar conhecimento.4 Participar dessa comunidade é a melhor maneira de se manter atualizado com os desenvolvimentos rápidos, descobrir novas ferramentas e técnicas, e continuar a aprimorar o ambiente de trabalho que foi meticulosamente construído. Seu desktop Hyprland nunca está verdadeiramente "terminado"; ele é um sistema vivo que evolui junto com suas habilidades e necessidades.

#### **Referências citadas**

1. Why does hyprland work better than GNOME? \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1jpw4nc/why\_does\_hyprland\_work\_better\_than\_gnome/](https://www.reddit.com/r/hyprland/comments/1jpw4nc/why_does_hyprland_work_better_than_gnome/)  
2. From GNOME to Hyprland? I'm Torn Between Productivity and Aesthetic Freedom \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/archlinux/comments/1kcoakm/from\_gnome\_to\_hyprland\_im\_torn\_between/](https://www.reddit.com/r/archlinux/comments/1kcoakm/from_gnome_to_hyprland_im_torn_between/)  
3. GNOME is VERY customizable \- The Linux Experiment \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/gnome/comments/tpqfdd/gnome\_is\_very\_customizable\_the\_linux\_experiment/](https://www.reddit.com/r/gnome/comments/tpqfdd/gnome_is_very_customizable_the_linux_experiment/)  
4. Can someone explain to me what Hyprland exactly is? \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1bej9lj/can\_someone\_explain\_to\_me\_what\_hyprland\_exactly\_is/](https://www.reddit.com/r/hyprland/comments/1bej9lj/can_someone_explain_to_me_what_hyprland_exactly_is/)  
5. Hyprland: estilo e produtividade redefinidos num TWM para Linux \- Diolinux, acessado em agosto 31, 2025, [https://diolinux.com.br/softwares/hyprland-twm-para-linux.html](https://diolinux.com.br/softwares/hyprland-twm-para-linux.html)  
6. hyprland-dotfiles · GitHub Topics, acessado em agosto 31, 2025, [https://github.com/topics/hyprland-dotfiles?l=css](https://github.com/topics/hyprland-dotfiles?l=css)  
7. hyprland · GitHub Topics, acessado em agosto 31, 2025, [https://github.com/topics/hyprland](https://github.com/topics/hyprland)  
8. Hyprland en Linux es IMPRESIONANTE \- YouTube, acessado em agosto 31, 2025, [https://www.youtube.com/watch?v=Q3TqEAXDmU0](https://www.youtube.com/watch?v=Q3TqEAXDmU0)  
9. \[GNOME\] I was thinking, why do I need hyprland when I have gnome, and why do I need to create a unique style each time when I have regular gnome and extensions like blur my shell? The main thing now is functionality and convenience, not uniqueness and the race for the table to be better than others \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/unixporn/comments/1edhmuh/gnome\_i\_was\_thinking\_why\_do\_i\_need\_hyprland\_when/](https://www.reddit.com/r/unixporn/comments/1edhmuh/gnome_i_was_thinking_why_do_i_need_hyprland_when/)  
10. What is Hyprland? \[SOLVED\] / Applications & Desktop Environments / Arch Linux Forums, acessado em agosto 31, 2025, [https://bbs.archlinux.org/viewtopic.php?id=285541](https://bbs.archlinux.org/viewtopic.php?id=285541)  
11. Hyprland, acessado em agosto 31, 2025, [https://hypr.land/](https://hypr.land/)  
12. Hyprland \- ArchWiki, acessado em agosto 31, 2025, [https://wiki.archlinux.org/title/Hyprland](https://wiki.archlinux.org/title/Hyprland)  
13. Hyprland \- Wikipedia, la enciclopedia libre, acessado em agosto 31, 2025, [https://es.wikipedia.org/wiki/Hyprland](https://es.wikipedia.org/wiki/Hyprland)  
14. Gnome or kde or hyprland ? : r/archlinux \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/archlinux/comments/1eqf9k6/gnome\_or\_kde\_or\_hyprland/](https://www.reddit.com/r/archlinux/comments/1eqf9k6/gnome_or_kde_or_hyprland/)  
15. Installation \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/Getting-Started/Installation/](https://wiki.hypr.land/Getting-Started/Installation/)  
16. Installation \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hyprland.org/0.41.0/Getting-Started/Installation/](https://wiki.hyprland.org/0.41.0/Getting-Started/Installation/)  
17. Installing the Much Hyped Hyprland on Linux \- It's FOSS, acessado em agosto 31, 2025, [https://itsfoss.com/install-hyprland/](https://itsfoss.com/install-hyprland/)  
18. MINDBLOWING NEW UBUNTU HYPRLAND SETUP (2025) // MAKE YOUR UBUNTU DESKTOP LOOK MODERN \- YouTube, acessado em agosto 31, 2025, [https://www.youtube.com/watch?v=kHsgbJLnO2I](https://www.youtube.com/watch?v=kHsgbJLnO2I)  
19. JaKooLit/Arch-Hyprland: For automated installation of Hyprland on Arch Linux or any Arch Linux-based distros \- GitHub, acessado em agosto 31, 2025, [https://github.com/JaKooLit/Arch-Hyprland](https://github.com/JaKooLit/Arch-Hyprland)  
20. For automated installation of Hyprland on Fedora (latest release) or any Fedora based distros \- GitHub, acessado em agosto 31, 2025, [https://github.com/JaKooLit/Fedora-Hyprland](https://github.com/JaKooLit/Fedora-Hyprland)  
21. Ubuntu 23.04 Build and Install instructions for Hyprland \- GitHub Gist, acessado em agosto 31, 2025, [https://gist.github.com/Vertecedoc4545/3b077301299c20c5b9b4db00f4ca6000](https://gist.github.com/Vertecedoc4545/3b077301299c20c5b9b4db00f4ca6000)  
22. Primeros pasos en Hyprland \- iAgosto Blog, acessado em agosto 31, 2025, [https://blog.iagosto.dev/entradas/primeros-pasos-en-hyprland](https://blog.iagosto.dev/entradas/primeros-pasos-en-hyprland)  
23. Como posso encontrar minhas teclas de atalho para o HyprLand? \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/15f97ue/how\_i\_do\_find\_my\_keybinds\_for\_hyprland/?tl=pt-br](https://www.reddit.com/r/hyprland/comments/15f97ue/how_i_do_find_my_keybinds_for_hyprland/?tl=pt-br)  
24. Status bars \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/Useful-Utilities/Status-Bars/](https://wiki.hypr.land/Useful-Utilities/Status-Bars/)  
25. Alexays/Waybar: Highly customizable Wayland bar for Sway and Wlroots based compositors. :tada \- GitHub, acessado em agosto 31, 2025, [https://github.com/Alexays/Waybar](https://github.com/Alexays/Waybar)  
26. Setup WAYBAR, the status bar for HYPRLAND with standard and custom modules for your window manager. \- YouTube, acessado em agosto 31, 2025, [https://www.youtube.com/watch?v=rW3JKs1\_oVI](https://www.youtube.com/watch?v=rW3JKs1_oVI)  
27. Hyprland \- Archcraft Wiki, acessado em agosto 31, 2025, [https://wiki.archcraft.io/docs/wayland-compositors/hyprland/](https://wiki.archcraft.io/docs/wayland-compositors/hyprland/)  
28. Deixe sua Waybar com estilo\! Personalize o painel no Hyprland \- YouTube, acessado em agosto 31, 2025, [https://m.youtube.com/watch?v=H9LqnbMspJQ](https://m.youtube.com/watch?v=H9LqnbMspJQ)  
29. davatorium/rofi: Rofi: A window switcher, application launcher and dmenu replacement, acessado em agosto 31, 2025, [https://github.com/davatorium/rofi](https://github.com/davatorium/rofi)  
30. App launchers \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/Useful-Utilities/App-Launchers/](https://wiki.hypr.land/Useful-Utilities/App-Launchers/)  
31. Rofi \- ArchWiki, acessado em agosto 31, 2025, [https://wiki.archlinux.org/title/Rofi](https://wiki.archlinux.org/title/Rofi)  
32. Set up Rofi App Launcher | Hyprland | Arch Linux \- YouTube, acessado em agosto 31, 2025, [https://www.youtube.com/watch?v=tD3NFVjeAts](https://www.youtube.com/watch?v=tD3NFVjeAts)  
33. Hyprland and notifications with mako \- Lorenzo Bettini, acessado em agosto 31, 2025, [https://www.lorenzobettini.it/2023/11/hyprland-and-notifications-with-mako/](https://www.lorenzobettini.it/2023/11/hyprland-and-notifications-with-mako/)  
34. Mako versus Dunst : r/hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1ajhnnh/mako\_versus\_dunst/](https://www.reddit.com/r/hyprland/comments/1ajhnnh/mako_versus_dunst/)  
35. Getting Hyprland \- Page 7 \- EndeavourOS Forum, acessado em agosto 31, 2025, [https://forum.endeavouros.com/t/getting-hyprland/40840?page=7](https://forum.endeavouros.com/t/getting-hyprland/40840?page=7)  
36. Wallpapers \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/Useful-Utilities/Wallpapers/](https://wiki.hypr.land/Useful-Utilities/Wallpapers/)  
37. LGFae/swww: A Solution to your Wayland Wallpaper Woes \- GitHub, acessado em agosto 31, 2025, [https://github.com/LGFae/swww](https://github.com/LGFae/swww)  
38. swww \> Hyprpaper? : r/hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1fnrl5d/swww\_hyprpaper/](https://www.reddit.com/r/hyprland/comments/1fnrl5d/swww_hyprpaper/)  
39. Why swww is not working properly? : r/hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1maiplc/why\_swww\_is\_not\_working\_properly/](https://www.reddit.com/r/hyprland/comments/1maiplc/why_swww_is_not_working_properly/)  
40. FAQ \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/FAQ/](https://wiki.hypr.land/FAQ/)  
41. Faq \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/hyprland-wiki/pages/FAQ/](https://wiki.hypr.land/hyprland-wiki/pages/FAQ/)  
42. The BEST way to take screen shots in Hyprland/Wayland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1eatxgg/the\_best\_way\_to\_take\_screen\_shots\_in/](https://www.reddit.com/r/hyprland/comments/1eatxgg/the_best_way_to_take_screen_shots_in/)  
43. Must have \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/Useful-Utilities/Must-have/](https://wiki.hypr.land/Useful-Utilities/Must-have/)  
44. Configuring \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hyprland.org/0.41.0/Configuring/Configuring-Hyprland/](https://wiki.hyprland.org/0.41.0/Configuring/Configuring-Hyprland/)  
45. Hyprland: guia básico para configuração e personalização \- Tecnosob, acessado em agosto 31, 2025, [https://tecnosob.com/hyprland-guia-basico-para-configuracao-e-personalizacao/](https://tecnosob.com/hyprland-guia-basico-para-configuracao-e-personalizacao/)  
46. hyprland.conf \- GitHub Gist, acessado em agosto 31, 2025, [https://gist.github.com/Shentxt/c749142e5df33f838c4f10d402cab70a](https://gist.github.com/Shentxt/c749142e5df33f838c4f10d402cab70a)  
47. Keybinds · JaKooLit/Hyprland-Dots Wiki \- GitHub, acessado em agosto 31, 2025, [https://github.com/JaKooLit/Hyprland-Dots/wiki/Keybinds](https://github.com/JaKooLit/Hyprland-Dots/wiki/Keybinds)  
48. Sugestões de atalhos de teclado necessárias : r/hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1i88x1l/keybinding\_suggestions\_needed/?tl=pt-br](https://www.reddit.com/r/hyprland/comments/1i88x1l/keybinding_suggestions_needed/?tl=pt-br)  
49. Window Rules \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/Configuring/Window-Rules/](https://wiki.hypr.land/Configuring/Window-Rules/)  
50. Window Rules \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hyprland.org/0.41.0/Configuring/Window-Rules/](https://wiki.hyprland.org/0.41.0/Configuring/Window-Rules/)  
51. Problema com reconhecimento de monitor no arch com hyprland \- Linux \- Diolinux Plus, acessado em agosto 31, 2025, [https://plus.diolinux.com.br/t/problema-com-reconhecimento-de-monitor-no-arch-com-hyprland/68923](https://plus.diolinux.com.br/t/problema-com-reconhecimento-de-monitor-no-arch-com-hyprland/68923)  
52. Monitors \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/Configuring/Monitors/](https://wiki.hypr.land/Configuring/Monitors/)  
53. Monitors \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hyprland.org/0.41.2/Configuring/Monitors/](https://wiki.hyprland.org/0.41.2/Configuring/Monitors/)  
54. Configurações do monitor Hyprland no arquivo de configuração sendo sobrescritas no login, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/18yx6ut/hyprland\_monitor\_settings\_in\_config\_getting/?tl=pt-br](https://www.reddit.com/r/hyprland/comments/18yx6ut/hyprland_monitor_settings_in_config_getting/?tl=pt-br)  
55. Hyprland | Phundrak's Dotfiles, acessado em agosto 31, 2025, [https://config.phundrak.com/hyprland](https://config.phundrak.com/hyprland)  
56. Hyprland theming. everything from getting themes/making them to loading them \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/14uk7s3/hyprland\_theming\_everything\_from\_getting/](https://www.reddit.com/r/hyprland/comments/14uk7s3/hyprland_theming_everything_from_getting/)  
57. I just can't set gtk theme... : r/hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1ixczr1/i\_just\_cant\_set\_gtk\_theme/](https://www.reddit.com/r/hyprland/comments/1ixczr1/i_just_cant_set_gtk_theme/)  
58. How to apply gtk themes on hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/17swxzh/how\_to\_apply\_gtk\_themes\_on\_hyprland/](https://www.reddit.com/r/hyprland/comments/17swxzh/how_to_apply_gtk_themes_on_hyprland/)  
59. Gtk theme in garuda\_hyprland \- Hyprland \- Garuda Linux Forum, acessado em agosto 31, 2025, [https://forum.garudalinux.org/t/gtk-theme-in-garuda-hyprland/38120](https://forum.garudalinux.org/t/gtk-theme-in-garuda-hyprland/38120)  
60. How do I apply dark theme : r/hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1h4abmt/how\_do\_i\_apply\_dark\_theme/](https://www.reddit.com/r/hyprland/comments/1h4abmt/how_do_i_apply_dark_theme/)  
61. JaKooLit/GTK-themes-icons \- GitHub, acessado em agosto 31, 2025, [https://github.com/JaKooLit/GTK-themes-icons](https://github.com/JaKooLit/GTK-themes-icons)  
62. \[Hyprland\] Blue, green and red : r/unixporn \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/unixporn/comments/1jlrjaa/hyprland\_blue\_green\_and\_red/](https://www.reddit.com/r/unixporn/comments/1jlrjaa/hyprland_blue_green_and_red/)  
63. hyprcursor \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/](https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/)  
64. hyprcursor \- Hyprland Standards, acessado em agosto 31, 2025, [https://standards.hyprland.org/hyprcursor/](https://standards.hyprland.org/hyprcursor/)  
65. Custom cursor changes back to default over certain programs : r/hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1iooolt/custom\_cursor\_changes\_back\_to\_default\_over/](https://www.reddit.com/r/hyprland/comments/1iooolt/custom_cursor_changes_back_to_default_over/)  
66. Variables \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/Configuring/Variables/](https://wiki.hypr.land/Configuring/Variables/)  
67. mylinuxforwork/dotfiles: The ML4W Dotfiles for Hyprland \- An advanced and full-featured configuration for the dynamic tiling window manager Hyprland. Ready to install with the Dotfiles Installer app with setup scripts for Arch, Fedora and openSuse. \- GitHub, acessado em agosto 31, 2025, [https://github.com/mylinuxforwork/dotfiles](https://github.com/mylinuxforwork/dotfiles)  
68. end-4/dots-hyprland: Rice built for usability \- GitHub, acessado em agosto 31, 2025, [https://github.com/end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)  
69. How To Rice : r/hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1al86c8/how\_to\_rice/](https://www.reddit.com/r/hyprland/comments/1al86c8/how_to_rice/)  
70. Gerenciamento Dinâmico de Janelas? : r/hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/14bar2w/dynamic\_window\_management/?tl=pt-br](https://www.reddit.com/r/hyprland/comments/14bar2w/dynamic_window_management/?tl=pt-br)  
71. How Do you work with hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1jl9ad1/how\_do\_you\_work\_with\_hyprland/](https://www.reddit.com/r/hyprland/comments/1jl9ad1/how_do_you_work_with_hyprland/)  
72. Creating additional workspaces : r/hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1ev1zcc/creating\_additional\_workspaces/](https://www.reddit.com/r/hyprland/comments/1ev1zcc/creating_additional_workspaces/)  
73. I created a dynamic workspaces switcher \- Create, name, rename workspaces, move windows and switch to any window easily. : r/hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1gww1uy/i\_created\_a\_dynamic\_workspaces\_switcher\_create/](https://www.reddit.com/r/hyprland/comments/1gww1uy/i_created_a_dynamic_workspaces_switcher_create/)  
74. How to Create Multiple “Special Workspaces” in Hyprland | by Ed \- Medium, acessado em agosto 31, 2025, [https://medium.com/@mynameised/how-to-create-multiple-special-workspaces-in-hyprland-b4de8bc2ddd7](https://medium.com/@mynameised/how-to-create-multiple-special-workspaces-in-hyprland-b4de8bc2ddd7)  
75. Part 3: Hyprland as Part of Your Development Workflow | Haseeb Majid, acessado em agosto 31, 2025, [https://haseebmajid.dev/posts/2023-11-15-part-3-hyprland-as-part-of-your-development-workflow/](https://haseebmajid.dev/posts/2023-11-15-part-3-hyprland-as-part-of-your-development-workflow/)  
76. How lightweight is Hyprland? \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/16i1qtr/how\_lightweight\_is\_hyprland/](https://www.reddit.com/r/hyprland/comments/16i1qtr/how_lightweight_is_hyprland/)  
77. Linux DE's resource usage compared \- All WMs \- EndeavourOS Forum, acessado em agosto 31, 2025, [https://forum.endeavouros.com/t/linux-des-resource-usage-compared/70060](https://forum.endeavouros.com/t/linux-des-resource-usage-compared/70060)  
78. Hyprland causes higher CPU temps than KDE/GNOME on my old laptop \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1lc9nnl/hyprland\_causes\_higher\_cpu\_temps\_than\_kdegnome\_on/](https://www.reddit.com/r/hyprland/comments/1lc9nnl/hyprland_causes_higher_cpu_temps_than_kdegnome_on/)  
79. Gnome vs Hyprland detailed comparison as of 2025 \- Slant Co, acessado em agosto 31, 2025, [https://www.slant.co/versus/12539/44102/\~gnome\_vs\_hyprland](https://www.slant.co/versus/12539/44102/~gnome_vs_hyprland)  
80. How bad really is the situation with nvidia and hyprland? : r/archlinux \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/archlinux/comments/1abh5ds/how\_bad\_really\_is\_the\_situation\_with\_nvidia\_and/](https://www.reddit.com/r/archlinux/comments/1abh5ds/how_bad_really_is_the_situation_with_nvidia_and/)  
81. Nvidia \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/hyprland-wiki/pages/Nvidia/](https://wiki.hypr.land/hyprland-wiki/pages/Nvidia/)  
82. NVidia \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hyprland.org/0.41.0/Nvidia/](https://wiki.hyprland.org/0.41.0/Nvidia/)  
83. \[SOLVED\]Nvidia GPU integrity check for Hyprland / Applications & Desktop Environments / Arch Linux Forums, acessado em agosto 31, 2025, [https://bbs.archlinux.org/viewtopic.php?id=291774](https://bbs.archlinux.org/viewtopic.php?id=291774)  
84. NVidia \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/Nvidia/](https://wiki.hypr.land/Nvidia/)  
85. Screen sharing \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hypr.land/Useful-Utilities/Screen-Sharing/](https://wiki.hypr.land/Useful-Utilities/Screen-Sharing/)  
86. Screen sharing on Hyprland (Arch Linux) \- GitHub Gist, acessado em agosto 31, 2025, [https://gist.github.com/brunoanc/2dea6ddf6974ba4e5d26c3139ffb7580](https://gist.github.com/brunoanc/2dea6ddf6974ba4e5d26c3139ffb7580)  
87. Screen sharing \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hyprland.org/0.41.0/Useful-Utilities/Screen-Sharing/](https://wiki.hyprland.org/0.41.0/Useful-Utilities/Screen-Sharing/)  
88. Does Discord screen sharing work? : r/hyprland \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1hv8f97/does\_discord\_screen\_sharing\_work/](https://www.reddit.com/r/hyprland/comments/1hv8f97/does_discord_screen_sharing_work/)  
89. Not able to share entire screen on discord in Hyprland \- Stack Overflow, acessado em agosto 31, 2025, [https://stackoverflow.com/questions/77590918/not-able-to-share-entire-screen-on-discord-in-hyprland](https://stackoverflow.com/questions/77590918/not-able-to-share-entire-screen-on-discord-in-hyprland)  
90. \[SOLVED\] Having trouble Screensharing in Hyprland / Newbie Corner / Arch Linux Forums, acessado em agosto 31, 2025, [https://bbs.archlinux.org/viewtopic.php?id=299426](https://bbs.archlinux.org/viewtopic.php?id=299426)  
91. Faq \- Hyprland Wiki, acessado em agosto 31, 2025, [https://wiki.hyprland.org/hyprland-wiki/pages/FAQ/](https://wiki.hyprland.org/hyprland-wiki/pages/FAQ/)  
92. How Are You Fixing Blurry Font on Electron Apps? \- General \- Hyprland Forum, acessado em agosto 31, 2025, [https://forum.hypr.land/t/how-are-you-fixing-blurry-font-on-electron-apps/456](https://forum.hypr.land/t/how-are-you-fixing-blurry-font-on-electron-apps/456)  
93. ¿Alguien me puede explicar qué es exactamente Hyprland? \- Reddit, acessado em agosto 31, 2025, [https://www.reddit.com/r/hyprland/comments/1bej9lj/can\_someone\_explain\_to\_me\_what\_hyprland\_exactly\_is/?tl=es-419](https://www.reddit.com/r/hyprland/comments/1bej9lj/can_someone_explain_to_me_what_hyprland_exactly_is/?tl=es-419)
