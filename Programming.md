# Tips and Tricks

Various tips and tricks in some programming languages.

## C and C++

### Returning a lambda

C++14

See `get_wait_predicate` in the following `Semaphore` example. It is essentially a
[higher-order function](https://en.wikipedia.org/wiki/Higher-order_function).
Note that no `std::function` wrapper is used.

<details><summary>Semaphore</summary>

```cpp
#include <chrono>
#include <condition_variable>
#include <mutex>

class Semaphore
{
    int m_count = 0;
    std::condition_variable m_cv;
    std::mutex m_mutex;

    auto get_wait_predicate() const
    {
        return [this]() -> bool { return m_count > 0; };
    }

public:
    explicit Semaphore(int count = 0) : m_count(count) {}

    void wait()
    {
        std::unique_lock lock(m_mutex);

        m_cv.wait(lock, this->get_wait_predicate());
        m_count--;
    }

    template<class Rep, class Period>
    bool wait_for(const std::chrono::duration<Rep, Period>& interval)
    {
        std::unique_lock lock(m_mutex);

        if (m_cv.wait_for(lock, interval, this->get_wait_predicate()))
        {
            m_count--;
            return true;
        }
        else
        {
            return false;
        }
    }

    void signal(int count = 1)
    {
        std::lock_guard lock(m_mutex);

        m_count += count;

        for (int i = 0; i < count; i++)
        {
            m_cv.notify_one();
        }
    }
};
```

</details>

### CTAD (Class Template Argument Deduction)

C++17

See `std::unique_lock` and `std::lock_guard` without an explicit template argument in the `Semaphore` example above.

Source: [cppreference.com](https://en.cppreference.com/w/cpp/language/class_template_argument_deduction)

### String literal indexing

```c
char to_hex_digit(unsigned int n)
{
    return "0123456789abcdef"[n & 15];
}
```

Source: [Bisqwit](https://www.youtube.com/watch?v=rwOI1biZeD8)

### Flexible array member

C99, non-standard in C++

```c
struct packed_string
{
    size_t length;
    char data[];
};
```

Source: [Wikipedia](https://en.wikipedia.org/wiki/Flexible_array_member),
[cppreference.com](https://en.cppreference.com/w/c/language/struct)

### Variable-length arrays

C99, non-standard in C++

Just out of curiosity. Better to avoid VLAs in general.

```c
void something(unsigned int count)
{
    int buffer[count];
    // ...
}
```

Source: [Wikipedia](https://en.wikipedia.org/wiki/Variable-length_array),
[cppreference.com](https://en.cppreference.com/w/c/language/array)

### X macro

<details><summary>Example</summary>

```c
#define LIST_OF_VARIABLES \
    X(some_value_a) \
    X(some_value_b) \
    X(some_value_c)

#define X(name) static int name;
LIST_OF_VARIABLES
#undef X

void print_variables()
{
#define X(name) printf(#name " = %d\n", name);
LIST_OF_VARIABLES
#undef X
}
```

</details>

Source: [Tsoding](https://www.youtube.com/watch?v=PgDqBZFir1A),
[Wikipedia](https://en.wikipedia.org/wiki/X_macro)

# Design Patterns

A design pattern:

- has a name
- carries an intent
- introduces an abstraction
- has been proven

## Type Erasure

<details><summary>Function</summary>

```cpp
#include <cstddef>
#include <memory>
#include <type_traits>
#include <utility>

template<class>
class Function;

template<class Ret, class... Params>
class Function<Ret(Params...)>
{
    struct Concept
    {
        virtual ~Concept() = default;
        virtual Ret call(Params&&... params) = 0;
        virtual std::unique_ptr<Concept> clone() const = 0;
    };

    template<class Functor>
    struct Model : public Concept
    {
        Functor functor;

        template<class T>
        explicit Model(T&& f) : functor(std::forward<T>(f)) {}

        Ret call(Params&&... params) override
        {
            return this->functor(std::forward<Params>(params)...);
        }

        std::unique_ptr<Concept> clone() const override
        {
            return std::make_unique<Model>(*this);
        }
    };

    std::unique_ptr<Concept> pImpl;

public:
    Function() = default;
    Function(Function&&) = default;
    Function& operator=(Function&&) = default;
    ~Function() = default;

    Function(std::nullptr_t) noexcept {}

    template<class T,
        std::enable_if_t<
            !std::is_same_v<std::decay_t<T>, Function>, bool
        > = true
    >
    Function(T&& f) : pImpl(
        std::make_unique<Model<std::decay_t<T>>>(
            std::forward<T>(f)
        )
    ) {}

    Function(const Function& other) : pImpl(
        other.pImpl ? other.pImpl->clone() : nullptr
    ) {}

    Function& operator=(const Function& other)
    {
        Function(other).swap(*this);
        return *this;
    }

    Function& operator=(std::nullptr_t) noexcept
    {
        this->pImpl = nullptr;
        return *this;
    }

    void swap(Function& other) noexcept
    {
        this->pImpl.swap(other.pImpl);
    }

    explicit operator bool() const noexcept
    {
        return static_cast<bool>(this->pImpl);
    }

    Ret operator()(Params... params) const
    {
        // TODO: throw some exception if empty

        return this->pImpl->call(std::forward<Params>(params)...);
    }
};
```

</details>

Source: [C++ Software Design book](https://www.oreilly.com/library/view/c-software-design/9781098113155/),
[CppCon](https://www.youtube.com/watch?v=qn6OqefuH08),
[C++ Weekly](https://www.youtube.com/watch?v=iMzEUdacznQ)
