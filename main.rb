# Encoding: UTF-8

require 'rubygems'
require 'gosu'
require 'celluloid/io'
require 'socket'
require 'securerandom'

WIDTH, HEIGHT = 1024, 768

class Client
  include Celluloid::IO

  def initialize(server, port)
    begin
      @socket = TCPSocket.new(server, port)
    rescue
      $error_message = "Cannot find game server."
    end
  end

  def send_message(message)
    @socket.write(message) if @socket
  end

  def read_message
    @socket.readpartial(4096) if @socket
  end
end

module BuffHelper
  def self.check_buffs(nave)
    check_vrumm(nave)
  end

  def self.check_vrumm(nave)
   if nave.buffs.include? :vrumm
     nave.move_offset += 1
   else
     nave.move_offset = 1
   end
  end
end

class Buff
  attr_accessor :type, :timer

  def initialize(type, nave, options = {})
    self.type = type 
    @nave = nave
    self.timer = options[:timer].nil? ? 3 : options[:timer]
    create
  end

  def create
    if @nave.buffs.include? type
      p "Already u have a #{type} buff"
    else
      p 'created!'
      @nave.buffs.push type
      Thread.start {
        self.destroy
      }
    end
  end

  def destroy
    sleep self.timer
    @nave.buffs.delete self.type
  end
end

class Nave
  attr_accessor :buffs, :move_offset
  attr_reader :uuid, :y, :x, :angle

  # metodo para criar um novo objeto da rede
  def self.from_sprite(window, sprite)
    Nave.new(window, sprite[1], sprite[2], sprite[3], sprite[4])
  end

  def initialize(window, uuid = SecureRandom.uuid, x = 0, y = 0, angle = 0.0)
    @window = self
    @skin = Gosu::Image.new("assets/images/aula/spaceship.png")
    @uuid = uuid
    @x = x.to_f
    @y = y.to_f
    @angle = angle.to_f
    @buffs = [] 
    @move_offset = 1
  end

  def stay(x, y)
    @x, @y = x, y
  end

  def move_left
    @x -= @move_offset
    @angle = 270.0
  end

  def move_right
    @x += @move_offset
    @angle = 90.0
  end

  def move_up
    @y -= @move_offset
    @angle = 0.0
  end

  def move_down
    @y += @move_offset
    @angle = 180.0
  end

  def check_axis
    @x = 0 if @x > WIDTH
    @x = WIDTH if @x < 0
    @y = 0 if @y > HEIGHT
    @y = HEIGHT if @y < 0
  end

  def draw
    check_axis
    @skin.draw_rot(@x, @y, 1, @angle)
  end
end

class GameWindow < Gosu::Window
  def initialize(server, port, uuid)
    super WIDTH, HEIGHT
    
    @client = Client.new(server, port)
    self.caption = "Gosu Game"

    # Mapa
    @background_image = Gosu::Image.new("assets/images/aula/space.bmp", :tileable => true)
    
    # O próprio jogador
    @nave = Nave.new(self)
    @nave.stay(300, 300)

    # Variaveis para troca de informações 
    @another_naves = Hash.new # Demais jogadores
    @messages = Array.new # Fila para troca de mensagens

    add_to_message_queue('player', @nave)
  end

  # Game handle connections
  # add a message to the queue to send to the server
  def add_to_message_queue(msg_type, object)
    message = [msg_type] # Cria o array de mensagens
    # Verificar todos os objetos em comum e partilhar entre os jogadores
    [:uuid, :x, :y, :angle].each do |instance|
       # Pega cada instancia do objeto e adiciona na mensagem 
       message.push(object.instance_variable_get("@#{instance}"))
    end
    @messages << message.join('|')
  end

  # Game methods
  def update
    BuffHelper::check_buffs(@nave)
    if Gosu::button_down? Gosu::KbLeft then
      @nave.move_left
    elsif Gosu::button_down? Gosu::KbRight then
      @nave.move_right
    elsif Gosu::button_down? Gosu::KbUp then
      @nave.move_up
    elsif Gosu::button_down? Gosu::KbDown then
      @nave.move_down
    elsif Gosu::button_down? Gosu::KbSpace then
      Buff.new :vrumm, @nave
    end
    add_to_message_queue('player', @nave) 

    # Envia para o socket as mensagens coletadas do jogador
    @client.send_message @messages.join("\n")
    @messages.clear

    # Faz a leitura de mensagens do servidor
    if msg = @client.read_message
      data = msg.split("\n")
      # verifica os objetos escritos em "arena.rb"
      data.each do |row|
        attributes = row.split("|")
        if attributes.size == 5
          uuid = attributes[1]
          unless @uuid == uuid # Garante que o objeto não seja o proprio jogador
            # Instancia a nova nave da rede localmente
            if attributes[0] == 'player'
              @another_naves[uuid] = Nave.from_sprite(self, attributes) 
            end
          end
        end
      end
    end
  end

  def draw
    @background_image.draw(0, 0, 0)
    @another_naves.each_value {|nave| nave.draw}
    @nave.draw
  end
end

# A variavel NAVESHIP_ARENA_PORT_5532_TCP_ADDR vem do link do docker, que pode ser visto com bin/docker_run
server, port = ARGV[0] || ENV['NAVESHIP_ARENA_PORT_5532_TCP_ADDR'], ARGV[1] || 5532
GameWindow.new(server, port, SecureRandom.uuid).show if __FILE__ == $0

