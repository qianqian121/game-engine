#pragma once
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <glm/mat4x4.hpp>
#include "ShaderPreprocessorElement.h"

#define LoadUniformLocation(uniformName) loadUniLocation(uniformName, #uniformName)
#define LoadUniformArrayLocation(uniformArrayName) loadUniArrayLocations(uniformArrayName, #uniformArrayName)

template<typename T>
class Uniform;

class Shader
{
private:
	unsigned int vs, fs;

	//caching for uniforms
	std::unordered_map<std::string, int> uniformLocationCache;
	std::vector<ShaderPreprocessorElement> vPreprocessorElements;
	std::vector<ShaderPreprocessorElement> fPreprocessorElements;

	std::string vertexFile, fragmentFile, shaderDirectory;
	std::unordered_set<std::string> includedFiles;
	unsigned int vsLineOffset, fsLineOffset;

protected:
	unsigned int rendererID;

	template<typename T>
	inline void loadUniLocation(Uniform<T>& uniform, const std::string& name)
	{
		uniform.loadLocation(name, *this);
	}
	
	template<typename T, unsigned int Size>
	inline void loadUniArrayLocations(std::array<Uniform<T>, Size>& uniforms, const std::string& name)
	{
		for (unsigned int i = 0; i < Size; i++)
			uniforms[i].loadLocation(name + "[" + std::to_string(i) + "]", *this);
	}

public:
	Shader(const std::string& vertexFile, const std::string& fragmentFile,
		std::vector<ShaderPreprocessorElement>&& vPreprocessors = std::vector<ShaderPreprocessorElement>(),
		std::vector<ShaderPreprocessorElement>&& fPreprocessors = std::vector<ShaderPreprocessorElement>());
	Shader(const Shader& other) = delete;
	Shader(Shader&& other);
	virtual ~Shader();

	Shader& operator=(const Shader& other) = delete;
	Shader& operator=(Shader&& other);

	void release();

	void bind() const;
	void unbind() const;

	inline int getProgramID() const { return rendererID; };
private:
	int getUniformLocation(const std::string& name);

	unsigned int compileShader(const std::string& source, unsigned int type);
	unsigned int createShader(const std::string& vertexShader, const std::string& fragmentShader);

	std::string readFile(const std::string& filename, const std::vector<ShaderPreprocessorElement>& preprocessor, unsigned int shaderType);
};
