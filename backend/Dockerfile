FROM node:20-alpine
WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json ./
RUN npm install --production

# Copy source code
COPY ./src ./src

# Expose API port
EXPOSE 3000

# Start the backend
CMD ["npm", "start"]
