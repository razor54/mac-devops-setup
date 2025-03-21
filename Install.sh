#!/bin/bash

printf "# Step 1 : Installing Xcode Command Line Tools"
xcode-select --install

echo "# Step 2 : Installing Homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Make sure brew is on the path
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/andregaudencio/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

brew doctor

echo "# Step 3 : Installing Python3"
brew install python
echo 'export PATH="/usr/local/opt/python/libexec/bin:$PATH"' >> ~/.zshrc
export PATH="/usr/local/opt/python/libexec/bin:$PATH"

# Install PIP -- No need anymore
# curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
# sudo python get-pip.py

echo "# Step 4 : Installing Ansible"
#sudo pip3 install ansible
brew install ansible

echo "# Step 5 : Installing Git"
brew install git

echo "# Step 6 : Installing Ansible dependency collections"
ansible-galaxy install -r requirements.yml

while true; do
    read -p "Would you like execute the playbook now? (y/n) " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) printf "\n Execute this command when you are ready:\n  ansible-playbook setup-my-mac.yml -i inventory -K \n" ; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo "# Running ansible setup"
ansible-playbook setup-my-mac.yml -i inventory -K

echo "# Step 7: install other tools"
# oh my zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone --depth=1 https://github.com/romkatv/powerlevel10k $ZSH_CUSTOM/themes/powerlevel10k

# Install vim color schemes 
git clone https://github.com/flazz/vim-colorschemes
mv vim-colorschemes/colors ~/maximum-awesome
rm -rf vim-colorschemes

# install zsh syntax highlight
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Install auto suggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Install nerdtree
git clone https://github.com/preservim/nerdtree.git ~/.vim/pack/vendor/start/nerdtree
vim -u NONE -c "helptags ~/.vim/pack/vendor/start/nerdtree/doc" -c q

# Disable mouse acceleration
defaults write .GlobalPreferences com.apple.mouse.scaling -1

# Install sdkman
curl -s "https://get.sdkman.io" | bash

# Copy and install the remap of capslock to control (make sure the folder exists)
mkdir -p ~/Library/KeyBindings
cp com.user.loginscript.plist ~/Library/LaunchAgents/
# Make sure the agent is loaded
launchctl load ~/Library/LaunchAgents/com.user.loginscript.plist

mkdir -p $HOME/.local/share/java/lombok
curl -o $HOME/.local/share/java/lombok/lombok.jar https://projectlombok.org/downloads/lombok.jar
