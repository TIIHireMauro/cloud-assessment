FROM node:24-alpine
WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json ./
RUN npm install --production

# Copy source code
COPY . .

# Start the simulator
CMD ["npm", "start"]
